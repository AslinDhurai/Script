#!/bin/bash
echo "Script ran at $(date)" >> /var/log/logrotate-script.log

# CONFIG
S3_BUCKET="s3-logcheck-bucket-annie"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
ROTATE_DIR="/var/log/logrotate-backup"
mkdir -p "$ROTATE_DIR"

# Rotate & compress Apache logs
for LOG in /var/log/apache2/*.log; do
    if [ -s "$LOG" ]; then
        BASE=$(basename "$LOG" .log)
        gzip -c "$LOG" > "$ROTATE_DIR/${BASE}_$TIMESTAMP.log.gz"
        : > "$LOG"
    fi
done



# Upload all .gz files to S3
for FILE in "$ROTATE_DIR"/*.gz; do
    aws s3 cp "$FILE" "s3://$S3_BUCKET/web-logs/"
done
