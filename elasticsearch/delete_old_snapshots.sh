#!/bin/bash

ES_HOST="http://localhost:9200"
REPO_NAME="my_repo"
RETENTION_DAYS=7

snapshots=$(curl -s -X GET "$ES_HOST/_snapshot/$REPO_NAME/_all" | jq -r '.snapshots[].snapshot')

for snapshot in $snapshots; do
  date_part=$(echo "$snapshot" | cut -d'-' -f2-)

  if [[ $date_part =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    snapshot_ts=$(date -d "$date_part" +%s)
    cutoff_ts=$(date -d "$RETENTION_DAYS days ago" +%s)

    if [ "$snapshot_ts" -lt "$cutoff_ts" ]; then
      echo "Deleting snapshot: $snapshot"
      curl -s -X DELETE "$ES_HOST/_snapshot/$REPO_NAME/$snapshot"
      echo "Snapshot $snapshot deleted at $(date)"
    fi
  fi
done

echo "Snapshot deletion completed at $(date)."
