import mysql.connector
import boto3
import datetime
import requests
import json
from dotenv import load_dotenv
import os

load_dotenv() 

# MySQL config
config = {
    "host": os.getenv("DB_HOST"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME")
}

SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL")


# State file to persist alert status across runs
STATE_FILE = "alert_state.json"

def get_previous_alert():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, 'r') as f:
                return json.load(f).get("alert", None)
        except json.JSONDecodeError:
            return None
    return None

def set_previous_alert(value):
    with open(STATE_FILE, 'w') as f:
        json.dump({"alert": value}, f)

def send_slack_alert(message):
    payload = {"text": message}
    try:
        requests.post(SLACK_WEBHOOK_URL, json=payload)
    except Exception as e:
        print(f"Slack alert failed: {e}")

def log_to_cloudwatch(log_msg):
    cloudwatch = boto3.client('logs', region_name=os.getenv("AWS_REGION"))
 # Adjust region if needed
    log_group = '/aws/rds/mysql-monitoring'
    log_stream = 'db-connection-logs'

    try:
        cloudwatch.create_log_group(logGroupName=log_group)
    except cloudwatch.exceptions.ResourceAlreadyExistsException:
        pass

    try:
        cloudwatch.create_log_stream(logGroupName=log_group, logStreamName=log_stream)
    except cloudwatch.exceptions.ResourceAlreadyExistsException:
        pass

    try:
        response = cloudwatch.describe_log_streams(logGroupName=log_group, logStreamNamePrefix=log_stream)
        sequence_token = response['logStreams'][0].get('uploadSequenceToken')
    except Exception as e:
        print(f"Error retrieving sequence token: {e}")
        sequence_token = None

    try:
        log_event = {
            'timestamp': int(datetime.datetime.now(datetime.timezone.utc).timestamp() * 1000),
            'message': log_msg
        }
        if sequence_token:
            cloudwatch.put_log_events(
                logGroupName=log_group,
                logStreamName=log_stream,
                logEvents=[log_event],
                sequenceToken=sequence_token
            )
        else:
            cloudwatch.put_log_events(
                logGroupName=log_group,
                logStreamName=log_stream,
                logEvents=[log_event]
            )
    except Exception as e:
        print(f"Error logging to CloudWatch: {e}")

def check_connections():
    previous_alert = get_previous_alert()
    conn = mysql.connector.connect(**config)
    cursor = conn.cursor()

    cursor.execute("SHOW STATUS LIKE 'Threads_connected'")
    active = int(cursor.fetchone()[1])

    cursor.execute("SHOW VARIABLES LIKE 'max_connections'")
    max_conn = int(cursor.fetchone()[1])

    percent = (active / max_conn) * 100
    db_id = config["host"]

    # Only log to CloudWatch for alert or normal state changes
    if percent > 80 and previous_alert != "alert_triggered":
        alert = f" ALERT: DB {db_id} connections at {percent:.2f}% ({active}/{max_conn})"
        print(alert)
        send_slack_alert(alert)
        log_to_cloudwatch(alert)  # Log alert to CloudWatch
        set_previous_alert("alert_triggered")

    elif percent < 75 and previous_alert == "alert_triggered":
        msg = f" DB {db_id} usage normal: {percent:.2f}%"
        print(msg)
        send_slack_alert(msg)
        log_to_cloudwatch(msg)  # Log normal status to CloudWatch
        set_previous_alert("normal_resolved")

    cursor.close()
    conn.close()

if __name__ == "__main__":
    check_connections()

