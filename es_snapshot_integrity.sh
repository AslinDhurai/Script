#!/bin/bash



ES_HOST="https://localhost:9200"
USER="elastic"
PASSWORD="2iF2jwHFyn1KbDeYRtxl"
REPO="my_local_repo"
SNAPSHOT="snapshot_1"
SOURCE_INDEX=".ds-ilm-history-7-2025.05.08-000001"
TARGET_INDEX="restored-ilm-history"
EXPECTED_COUNT=3

print_json() {
  echo -e "$1" | jq .
}


echo "{ \"step\": \"check_exists\", \"status\": \"info\", \"message\": \"Checking if [$TARGET_INDEX] already exists...\" }"
EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -u "$USER:$PASSWORD" -k "$ES_HOST/$TARGET_INDEX")
if [ "$EXISTS" -eq 200 ]; then
  echo "{ \"step\": \"check_exists\", \"status\": \"skipped\", \"message\": \"Index [$TARGET_INDEX] already exists. Skipping restore.\" }"
else
  echo "{ \"step\": \"restore\", \"status\": \"info\", \"message\": \"Restoring snapshot [$SNAPSHOT] to index [$TARGET_INDEX]...\" }"
  RESTORE_RESPONSE=$(curl -s -u "$USER:$PASSWORD" -k -X POST "$ES_HOST/_snapshot/$REPO/$SNAPSHOT/_restore" -H 'Content-Type: application/json' -d"
  {
    \"indices\": \"$SOURCE_INDEX\",
    \"rename_pattern\": \"$SOURCE_INDEX\",
    \"rename_replacement\": \"$TARGET_INDEX\",
    \"include_global_state\": false
  }")
  print_json "$RESTORE_RESPONSE"

  echo "{ \"step\": \"wait_for_restore\", \"status\": \"info\", \"message\": \"Waiting for index [$TARGET_INDEX] to restore...\" }"
  until curl -s -u "$USER:$PASSWORD" -k "$ES_HOST/$TARGET_INDEX/_stats" | jq -e .; do
  sleep 1
done

  echo "{ \"step\": \"wait_for_restore\", \"status\": \"success\", \"message\": \"Index [$TARGET_INDEX] restored.\" }"
fi


echo "{ \"step\": \"verify_count\", \"status\": \"info\", \"message\": \"Checking document count in [$TARGET_INDEX]...\" }"
DOC_COUNT=$(curl -s -u "$USER:$PASSWORD" -k "$ES_HOST/$TARGET_INDEX/_count" | jq -r .count)
if [ "$DOC_COUNT" == "$EXPECTED_COUNT" ]; then
  echo "{ \"step\": \"verify_count\", \"status\": \"success\", \"doc_count\": $DOC_COUNT, \"message\": \"Document count matches expected value.\" }"
else
  echo "{ \"step\": \"verify_count\", \"status\": \"error\", \"doc_count\": $DOC_COUNT, \"expected\": $EXPECTED_COUNT, \"message\": \"Mismatch in document count.\" }"
  exit 1
fi


echo "{ \"step\": \"index_metadata\", \"status\": \"info\", \"message\": \"Index metadata for [$TARGET_INDEX]:\" }"
curl -s -u "$USER:$PASSWORD" -k "$ES_HOST/$TARGET_INDEX" | jq .


echo "{ \"step\": \"sample_docs\", \"status\": \"info\", \"message\": \"Fetching 5 sample documents from [$TARGET_INDEX]...\" }"
curl -s -u "$USER:$PASSWORD" -k -X GET "$ES_HOST/$TARGET_INDEX/_search" -H 'Content-Type: application/json' -d'
{
  "size": 5
}' | jq .

echo "{ \"step\": \"complete\", \"status\": \"success\", \"message\": \"Snapshot restore verified and data previewed.\" }"
