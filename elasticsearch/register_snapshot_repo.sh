#!/bin/bash

ES_HOST="http://localhost:9200"
REPO_NAME="my_repo"
S3_BUCKET="es-snapshotsbucket"
AWS_REGION="us-east-1"

curl -X PUT "$ES_HOST/_snapshot/$REPO_NAME" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"s3\",
    \"settings\": {
      \"bucket\": \"$S3_BUCKET\",
      \"region\": \"$AWS_REGION\"
    }
  }"
