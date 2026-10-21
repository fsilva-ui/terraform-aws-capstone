#!/bin/bash
set -euo pipefail

RDS_HOST="${1:?Missing RDS endpoint}"
RDS_SECRET_ARN="${2:?Missing RDS secret ARN}"
AWS_REGION="${3:?Missing AWS Region}"
CONFIRMATION="${4:?Missing reset confirmation}"

if [[ "$CONFIRMATION" != "RESET-NEXTCLOUD-DEMO" ]]; then
  echo "Reset confirmation is invalid."
  exit 1
fi

export RDS_HOST

# Confirm that the recovery backup is available before changing anything.
aws s3api head-object \
  --bucket "capstone-dr-backup-09fe67283132d70dfc41ad680a" \
  --key "nextcloud/nextcloud-dr-backup-2026-10-04.tar.gz" \
  --region "$AWS_REGION" > /dev/null

# Confirm that this Nextcloud installation uses the expected RDS endpoint.
php <<'PHP'
<?php
include "/var/www/nextcloud/config/config.php";

if (($CONFIG["dbhost"] ?? "") !== getenv("RDS_HOST")) {
    file_put_contents(
        "php://stderr",
        "Unexpected database host. Reset cancelled.\n"
    );
    exit(1);
}
PHP

# Secure temporary storage for the administrative credentials.
umask 077
RESET_TEMP_DIR=$(mktemp -d /root/nextcloud-reset.XXXXXX)
trap 'rm -rf -- "$RESET_TEMP_DIR"' EXIT

export RDS_SECRET_FILE="$RESET_TEMP_DIR/secret.json"

aws secretsmanager get-secret-value \
  --secret-id "$RDS_SECRET_ARN" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text > "$RDS_SECRET_FILE"

# Stop application access before resetting the database.
runuser -u apache -- php /var/www/nextcloud/occ maintenance:mode --on

systemctl stop httpd
systemctl stop php-fpm

# Reset only the Nextcloud database.
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

    $db->ssl_set(
        null,
        null,
        "/etc/pki/rds/global-bundle.pem",
        null,
        null
    );

    $db->real_connect(
        getenv("RDS_HOST"),
        $secret["username"],
        $secret["password"],
        null,
        3306,
        null,
        MYSQLI_CLIENT_SSL
    );

    $db->query("DROP DATABASE IF EXISTS `nextcloud`");

    $db->query(
        "CREATE DATABASE `nextcloud`
         CHARACTER SET utf8mb4
         COLLATE utf8mb4_general_ci"
    );

    echo "The nextcloud database was reset and is now empty.\n";
} catch (Throwable $error) {
    file_put_contents(
        "php://stderr",
        "Database reset failed. Keep the application stopped and inspect the execution.\n"
    );
    exit(1);
}
PHP

echo "Demo reset completed. The application remains stopped."