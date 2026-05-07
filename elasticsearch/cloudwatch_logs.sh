#!/bin/bash

LOG_GROUP="es-snapshot-logs"
LOG_STREAM="snapshot-script"
MESSAGE=${1:-"Snapshot job run at $(date)"}

aws logs create-log-group --log-group-name "$LOG_GROUP" 2>/dev/null
aws logs create-log-stream --log-group-name "$LOG_GROUP" --log-stream-name "$LOG_STREAM" 2>/dev/null

timestamp=$(date +%s%3N)

aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events timestamp="$timestamp",message="$MESSAGE"
