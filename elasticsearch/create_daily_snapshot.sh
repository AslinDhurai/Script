#!/bin/bash

ES_HOST="http://localhost:9200"
REPO_NAME="my_repo"
DATE=$(date +%F-%H-%M)
SNAPSHOT_NAME="snapshot-$DATE"
LOG_SCRIPT="$HOME/snapshots/cloudwatch_logs.sh"

"$LOG_SCRIPT" "Snapshot creation started: $SNAPSHOT_NAME"

EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "$ES_HOST/_snapshot/$REPO_NAME/$SNAPSHOT_NAME")

if [ "$EXISTS" -eq 200 ]; then
  echo "Snapshot $SNAPSHOT_NAME already exists. Skipping."
  "$LOG_SCRIPT" "Snapshot already exists: $SNAPSHOT_NAME"
  exit 0
fi

echo "Creating snapshot: $SNAPSHOT_NAME"
response=$(curl -s -X PUT "$ES_HOST/_snapshot/$REPO_NAME/$SNAPSHOT_NAME" \
  -H "Content-Type: application/json" \
  -d '{
    "indices": "*",
    "ignore_unavailable": true,
    "include_global_state": false
  }')

"$LOG_SCRIPT" "Snapshot creation response: $response"

echo "Snapshot $SNAPSHOT_NAME creation completed at $(date)."
