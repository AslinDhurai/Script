Register Snapshot Repo:
 #!/bin/bash
curl -X PUT "http://localhost:9200/_snapshot/my_repo" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "s3",
    "settings": {
      "bucket": "es-snapshotsbucket",
      "region": "us-east-1"
    }
  }'

Create Daily Snapshots:
#!/bin/bash

ES_HOST="http://localhost:9200"
REPO_NAME="my_repo"
DATE=$(date +%F-%H-%M)
SNAPSHOT_NAME="snapshot-$DATE"

LOG_SCRIPT="$HOME/snapshots/cloudwatch_logs.sh"  # Correct path to your logging script

# Log the start of the job
$LOG_SCRIPT "Snapshot creation started: $SNAPSHOT_NAME"

# Check if snapshot already exists
EXISTS=$(curl -s -o /dev/null -w "%{http_code}" "$ES_HOST/_snapshot/$REPO_NAME/$SNAPSHOT_NAME")

# If the snapshot already exists, skip creation
if [ "$EXISTS" -eq 200 ]; then
  echo "Snapshot $SNAPSHOT_NAME already exists. Skipping."
  $LOG_SCRIPT "Snapshot already exists: $SNAPSHOT_NAME"
  exit 0
fi

# Create the snapshot if it doesn't already exist
echo "Creating snapshot: $SNAPSHOT_NAME"
response=$(curl -s -X PUT "$ES_HOST/_snapshot/$REPO_NAME/$SNAPSHOT_NAME" \
  -H "Content-Type: application/json" \
  -d '{
    "indices": "*",
    "ignore_unavailable": true,
    "include_global_state": false
  }')

# Log the response from the snapshot creation API
$LOG_SCRIPT "Snapshot creation response: $response"

echo "Snapshot $SNAPSHOT_NAME creation completed at $(date)."


Delete Snapshots:
#!/bin/bash

ES_HOST="http://localhost:9200"
REPO_NAME="my_repo"
RETENTION_DAYS=7
LOG_SCRIPT="$HOME/snapshots/cloudwatch_logs.sh"

# Get all snapshots
snapshots=$(curl -s -X GET "$ES_HOST/_snapshot/$REPO_NAME/_all" | jq -r '.snapshots[].snapshot')

for snapshot in $snapshots; do
  # Extract date part
  DATE_PART=$(echo $snapshot | cut -d'-' -f2-)

  if [[ $DATE_PART =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    SNAP_TS=$(date -d "$DATE_PART" +%s)
    CUTOFF_TS=$(date -d "$RETENTION_DAYS days ago" +%s)

    if [ "$SNAP_TS" -lt "$CUTOFF_TS" ]; then
      echo "Deleting snapshot: $snapshot"
      curl -s -X DELETE "$ES_HOST/_snapshot/$REPO_NAME/$snapshot"
      echo "Snapshot $snapshot deleted at $(date)"
    fi
  fi
done

echo "Snapshot deletion completed at $(date)."

Cloudwatch Logs:

#!/bin/bash

LOG_GROUP="es-snapshot-logs"
LOG_STREAM="snapshot-script"

aws logs create-log-group --log-group-name "$LOG_GROUP" 2>/dev/null
aws logs create-log-stream --log-group-name "$LOG_GROUP" --log-stream-name "$LOG_STREAM" 2>/dev/null

TIMESTAMP=$(date +%s%3N)
MESSAGE="Snapshot job run at $(date)"

aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events timestamp=$TIMESTAMP,message="$MESSAGE"
