#!/bin/bash

THRESHOLD=90
EMAIL="archanavigneswaran579@gmail.com"
HOST=$(hostname)
DATE=$(date)

df -h --output=target,pcent | tail -n +2 | while read mount usage; do
    usage_val=$(echo "$usage" | tr -d '%')

    if [ "$usage_val" -ge "$THRESHOLD" ]; then
        SUBJECT="Disk Alert: $HOST - $mount at ${usage}"
        BODY="ALERT: On host $HOST, disk usage on mount point '$mount' has reached $usage as of $DATE."

        echo -e "Subject: $SUBJECT\n\n$BODY" | /usr/sbin/sendmail "$EMAIL"
    fi
done
