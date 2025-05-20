Schema Migration:
#!/bin/bash

SOURCE_DB_USER="mydbuser"
SOURCE_DB_PASS="rayyan@22"
SOURCE_DB_NAME="source_db"

TARGET_DB_NAME="target_db"
EC2_USER="ubuntu"
EC2_IP="3.80.134.18"
EC2_KEY_PATH="~/.ssh/mykey.pem"

REMOTE_SCHEMA_PATH="/home/ubuntu/schema_dump.sql"

TARGET_DB_USER="target_user"
TARGET_DB_PASS="target_pass"

echo "Exporting schema from source database..."
mysqldump -u "$SOURCE_DB_USER" -p"$SOURCE_DB_PASS" --routines --triggers --single-transaction "$SOURCE_DB_NAME" > schema_dump.sql

echo "Transferring schema to EC2 instance..."
scp -i "$EC2_KEY_PATH" schema_dump.sql "$EC2_USER@$EC2_IP:$REMOTE_SCHEMA_PATH"

echo "Connecting to EC2 and importing schema..."
ssh -i "$EC2_KEY_PATH" "$EC2_USER@$EC2_IP" bash <<EOF
  echo "Creating target database..."
  mysql -u "$TARGET_DB_USER" -p"$TARGET_DB_PASS" -e "CREATE DATABASE IF NOT EXISTS $TARGET_DB_NAME;"

  echo "Importing schema..."
  mysql -u "$TARGET_DB_USER" -p"$TARGET_DB_PASS" "$TARGET_DB_NAME" < "$REMOTE_SCHEMA_PATH"
EOF

echo " Migration completed."
