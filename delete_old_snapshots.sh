#!/bin/bash

echo "Fetching snapshots..."

# Set threshold date (30 days ago)
threshold_date=$(date -d '30 days ago' --utc +%Y-%m-%dT%H:%M:%S.000Z)

# Fetch all snapshots owned by self
snapshots=$(aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[?StartTime<'$threshold_date']" \
  --output json)

# Print all current snapshots older than 30 days
echo -e "\nSnapshots older than 30 days:"
echo "$snapshots" | jq -r '.[] | "\(.SnapshotId)\t\(.StartTime)"'

# Loop through and evaluate deletion
echo -e "\nEvaluating snapshots for deletion..."

echo "$snapshots" | jq -r '.[] | .SnapshotId' | while read snapshot_id; do
  # Check for keep-forever tag
  tag_value=$(aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$snapshot_id" "Name=key,Values=keep-forever" \
    --query "Tags[0].Value" --output text 2>/dev/null)

  if [[ "$tag_value" == "true" ]]; then
    echo "Skipping snapshot (keep-forever): $snapshot_id"
  else
    echo "Deleting snapshot: $snapshot_id"
    aws ec2 delete-snapshot --snapshot-id "$snapshot_id"
  fi
done

# Optional: Show ALL current snapshots still alive (not filtered by age)
echo -e "\nAll current snapshots (regardless of age):"
aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[*].[SnapshotId,StartTime]" \
  --output table

