#!/bin/bash

# === CONFIG ===
SOURCE_DB="my-source-db"
REGION="us-east-2"
DB_NAME="sample_db"
TABLE_NAME="employees"
BUCKET_NAME="awsbucketavk"
TEST_DB_ID="test-db-$(date +%Y%m%d%H%M%S)"

# === STEP 0: Get latest snapshot ID ===
SNAPSHOT_ID=$(aws rds describe-db-snapshots \
  --db-instance-identifier $SOURCE_DB \
  --query 'reverse(sort_by(DBSnapshots, &SnapshotCreateTime))[0].DBSnapshotIdentifier' \
  --region $REGION \
  --output text)

if [ "$SNAPSHOT_ID" == "None" ] || [ -z "$SNAPSHOT_ID" ]; then
  echo "No valid snapshot found. Exiting."
  exit 1
fi

echo "Restoring from snapshot: $SNAPSHOT_ID"

# === STEP 1: Restore snapshot ===
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier $TEST_DB_ID \
  --db-snapshot-identifier $SNAPSHOT_ID \
  --db-instance-class db.t3.micro \
  --publicly-accessible \
  --region $REGION

echo "Waiting for DB to become available..."
aws rds wait db-instance-available --db-instance-identifier $TEST_DB_ID --region $REGION

# === STEP 2: Get endpoint ===
ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $TEST_DB_ID \
  --query 'DBInstances[0].Endpoint.Address' \
  --region $REGION --output text)

echo "Endpoint: $ENDPOINT"
sleep 30  # Ensure DB is ready to accept connections

# === STEP 3: Run sanity queries ===
LOG_FILE="sanity_log.txt"
echo "Sanity query results:" > $LOG_FILE

# Row count
echo "Row count in '$TABLE_NAME':" >> $LOG_FILE
mysql -h $ENDPOINT -D $DB_NAME --silent -e "SELECT COUNT(*) FROM $TABLE_NAME;" >> $LOG_FILE 2>&1

# List tables
echo -e "\nList of tables in '$DB_NAME':" >> $LOG_FILE
mysql -h $ENDPOINT -D $DB_NAME --silent -e "SHOW TABLES;" >> $LOG_FILE 2>&1

# Table schema
echo -e "\nSchema of '$TABLE_NAME':" >> $LOG_FILE
mysql -h $ENDPOINT -D $DB_NAME --silent -e "DESCRIBE $TABLE_NAME;" >> $LOG_FILE 2>&1

# Integrity check: NULL values in each column
echo -e "\nIntegrity check for NULL values in each column:" >> $LOG_FILE
for col in $(mysql -h $ENDPOINT -D $DB_NAME --silent -e "SHOW COLUMNS FROM $TABLE_NAME;" | awk '{print $1}'); do
  mysql -h $ENDPOINT -D $DB_NAME --silent -e "SELECT COUNT(*) AS NullCount FROM $TABLE_NAME WHERE $col IS NULL;" >> $LOG_FILE 2>&1
done

# === STEP 4: Upload log to S3 ===
aws s3 cp $LOG_FILE s3://$BUCKET_NAME/rds-validation-logs/sanity_$(date +%Y%m%d%H%M%S).txt

# === STEP 5: Delete test DB ===
aws rds delete-db-instance \
  --db-instance-identifier $TEST_DB_ID \
  --skip-final-snapshot \
  --region $REGION

echo "Waiting for test DB to be deleted..."
aws rds wait db-instance-deleted --db-instance-identifier $TEST_DB_ID --region $REGION

echo " Process completed successfully!"