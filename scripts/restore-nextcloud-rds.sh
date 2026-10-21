#!/bin/bash
set -euo pipefail

exec > >(tee -a /var/log/nextcloud-restore.log) 2>&1

echo "Starting Nextcloud Disaster Recovery"

BUCKET="capstone-dr-backup-09fe67283132d70dfc41ad680a"
BACKUP="nextcloud-dr-backup-2026-10-04.tar.gz"
NEXTCLOUD="/var/www/nextcloud"
RDS_HOST="${2:?Missing RDS endpoint}"
RDS_SECRET_ARN="${3:?Missing RDS secret ARN}"
AWS_REGION="${4:?Missing AWS Region}"

# 1. Install required packages
dnf install -y \
  httpd \
  mariadb105 \
  php8.4 \
  php8.4-fpm \
  php8.4-mysqlnd \
  php8.4-gd \
  php8.4-mbstring \
  php8.4-intl \
  php8.4-xml \
  php8.4-zip \
  php8.4-bcmath \
  php8.4-gmp \
  wget \
  tar \
  bzip2

# 2. Start PHP
systemctl enable --now php-fpm

# 3. Configure PHP memory
sed -i 's/^memory_limit = .*/memory_limit = 512M/' /etc/php.ini

# 4. Download Nextcloud
cd /var/www

wget -q https://download.nextcloud.com/server/releases/nextcloud-35.0.1.tar.bz2
tar -xjf nextcloud-35.0.1.tar.bz2
rm nextcloud-35.0.1.tar.bz2

# 5. Download backup from S3
mkdir -p /restore

aws s3 cp \
  "s3://${BUCKET}/nextcloud/${BACKUP}" \
  "/restore/${BACKUP}"

tar -xzf "/restore/${BACKUP}" -C /restore

# 6. Restore Nextcloud files
tar -xzf /restore/nextcloud-dr/nextcloud-config.tar.gz -C "$NEXTCLOUD"
tar -xzf /restore/nextcloud-dr/nextcloud-data.tar.gz -C "$NEXTCLOUD"
tar -xzf /restore/nextcloud-dr/nextcloud-apps.tar.gz -C "$NEXTCLOUD"

chown -R apache:apache "$NEXTCLOUD"

# Download the AWS certificate bundle for RDS connections
RDS_CA="/etc/pki/rds/global-bundle.pem"

mkdir -p /etc/pki/rds

curl -fsS --retry 3 \
  https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
  -o "$RDS_CA"

chmod 644 "$RDS_CA"

# 7. Prepare the RDS connection and Nextcloud database user
umask 077

RDS_TEMP_DIR=$(mktemp -d /root/nextcloud-rds.XXXXXX)
trap 'rm -rf -- "$RDS_TEMP_DIR"' EXIT

export RDS_HOST RDS_CA NEXTCLOUD
export RDS_SECRET_FILE="$RDS_TEMP_DIR/secret.json"
export RDS_CLIENT_FILE="$RDS_TEMP_DIR/client.cnf"

aws secretsmanager get-secret-value \
  --secret-id "$RDS_SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text > "$RDS_SECRET_FILE"

php <<'PHP'
<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

try {
    $secret = json_decode(
        file_get_contents(getenv("RDS_SECRET_FILE")),
        true,
        512,
        JSON_THROW_ON_ERROR
    );

    $db = mysqli_init();
    $db->options(MYSQLI_OPT_CONNECT_TIMEOUT, 15);
    $db->options(MYSQLI_OPT_SSL_VERIFY_SERVER_CERT, true);
    $db->ssl_set(null, null, getenv("RDS_CA"), null, null);

    $db->real_connect(
        getenv("RDS_HOST"),
        $secret["username"],
        $secret["password"],
        "nextcloud",
        3306,
        null,
        MYSQLI_CLIENT_SSL
    );

    $db->set_charset("utf8mb4");

    $result = $db->query(
        "SELECT COUNT(*) FROM information_schema.tables
         WHERE table_schema = 'nextcloud'"
    );

    if ((int) $result->fetch_row()[0] > 0) {
        throw new RuntimeException("The destination database is not empty.");
    }

    include getenv("NEXTCLOUD") . "/config/config.php";

    $appUser = $db->real_escape_string($CONFIG["dbuser"]);
    $appPassword = $db->real_escape_string($CONFIG["dbpassword"]);

    $db->query(
        "CREATE USER IF NOT EXISTS '$appUser'@'%'
         IDENTIFIED BY '$appPassword'"
    );

    $db->query(
        "ALTER USER '$appUser'@'%'
         IDENTIFIED BY '$appPassword' REQUIRE SSL"
    );

    $db->query(
        "GRANT ALL PRIVILEGES ON nextcloud.* TO '$appUser'@'%'"
    );

    function optionValue($value) {
        return '"' . addcslashes($value, "\\\"\n\r") . '"';
    }

    $clientConfig =
        "[client]\n" .
        "host=" . optionValue(getenv("RDS_HOST")) . "\n" .
        "user=" . optionValue($secret["username"]) . "\n" .
        "password=" . optionValue($secret["password"]) . "\n" .
        "port=3306\n" .
        "ssl-ca=" . optionValue(getenv("RDS_CA")) . "\n" .
        "ssl-verify-server-cert\n";

    if (file_put_contents(
        getenv("RDS_CLIENT_FILE"),
        $clientConfig
    ) === false) {
        throw new RuntimeException("Could not write client configuration.");
    }

    echo "RDS connection and application user prepared.\n";
} catch (Throwable $error) {
    file_put_contents(
        "php://stderr",
        "RDS preparation failed. Check connectivity, credentials and whether the destination database is empty.\n"
    );
    exit(1);
}
PHP

# 8. Restore the database to RDS and update Nextcloud configuration
gunzip -c /restore/nextcloud-dr/nextcloud-db.sql.gz |
  mariadb --defaults-extra-file="$RDS_CLIENT_FILE" nextcloud

php <<'PHP'
<?php
$configFile = getenv("NEXTCLOUD") . "/config/config.php";
include $configFile;

$CONFIG["dbhost"] = getenv("RDS_HOST");
$CONFIG["dbport"] = 3306;
$CONFIG["dbname"] = "nextcloud";

$CONFIG["dbdriveroptions"][PDO::MYSQL_ATTR_SSL_CA] = getenv("RDS_CA");
$CONFIG["dbdriveroptions"][PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT] = true;

$content = "<?php\n\$CONFIG = " . var_export($CONFIG, true) . ";\n";

if (file_put_contents($configFile, $content) === false) {
    file_put_contents(
        "php://stderr",
        "Could not update Nextcloud database configuration.\n"
    );
    exit(1);
}
PHP

chown apache:apache "$NEXTCLOUD/config/config.php"

rm -rf -- "$RDS_TEMP_DIR"
trap - EXIT

# 9. Configure Apache
cat > /etc/httpd/conf.d/nextcloud.conf <<'APACHE'
DocumentRoot "/var/www/nextcloud"

<Directory "/var/www/nextcloud">
    Require all granted
    AllowOverride All
    Options FollowSymLinks
</Directory>
APACHE

# 10. Configure Nextcloud URL
ALB_DNS="${1:?Missing ALB DNS name}"

cd "$NEXTCLOUD"

runuser -u apache -- php occ config:system:set trusted_domains 1 \
  --value="$ALB_DNS"

runuser -u apache -- php occ config:system:set overwrite.cli.url \
  --value="http://$ALB_DNS"

runuser -u apache -- php occ config:system:set overwritehost \
  --value="$ALB_DNS"

runuser -u apache -- php occ config:system:set overwriteprotocol \
  --value="http"

runuser -u apache -- php occ config:system:set overwritewebroot \
  --value="/"

# 11. Start web server
systemctl enable --now httpd
systemctl restart php-fpm

# 12. Disable maintenance mode
runuser -u apache -- php occ maintenance:mode --off

# 13. Verify recovery
runuser -u apache -- php occ status

echo "Nextcloud Disaster Recovery completed" 