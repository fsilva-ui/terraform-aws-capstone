#!/bin/bash
set -euo pipefail

exec > >(tee -a /var/log/nextcloud-restore.log) 2>&1

echo "Starting Nextcloud Disaster Recovery"

BUCKET="capstone-dr-backup-09fe67283132d70dfc41ad680a"
BACKUP="nextcloud-dr-backup-2026-10-04.tar.gz"
NEXTCLOUD="/var/www/nextcloud"

# 1. Install required packages
dnf install -y \
  httpd \
  mariadb105-server \
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

# 2. Start database and PHP
systemctl enable --now mariadb
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

# 7. Create database
mariadb -e \
  "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

# Read database password from restored configuration.
# The password is never written to GitHub or printed in the logs.
php -r '
include "/var/www/nextcloud/config/config.php";

$db = mysqli_connect("localhost", "root", "");

if (!$db) {
    exit(1);
}

$password = mysqli_real_escape_string($db, $CONFIG["dbpassword"]);

echo "CREATE USER IF NOT EXISTS '\''nextcloud'\''@'\''localhost'\'' IDENTIFIED BY '\''" .
$password . "'\'';\n";
' | mariadb

mariadb -e \
  "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';"

# 8. Restore database
gunzip -c /restore/nextcloud-dr/nextcloud-db.sql.gz | mariadb nextcloud

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
TOKEN=$(curl -fsS -X PUT \
  http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60")

PUBLIC_IP=$(curl -fsS \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

cd "$NEXTCLOUD"

runuser -u apache -- php occ config:system:set trusted_domains 1 \
  --value="$PUBLIC_IP"

runuser -u apache -- php occ config:system:set overwrite.cli.url \
  --value="http://$PUBLIC_IP"

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