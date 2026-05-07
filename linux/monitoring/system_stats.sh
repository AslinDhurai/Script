#!/bin/bash

# Simplified System Metrics Collector

# Configuration
OUTPUT_FORMAT=${1:-"json"}  # json or csv
LOG_DIR="$HOME/system_stats"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$LOG_DIR"

# Get system metrics
get_metrics() {
    # CPU Usage (%)
    CPU=$(top -bn1 | awk '/Cpu\(s\):/ {print 100 - $8}')

    # Memory Usage (MB)
    MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
    MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

    # Disk Usage (%)
    DISK_USAGE=$(df -h --output=source,pcent | awk 'NR>1 {print $1,$2}' | tr -d '%')

    # Network Connections
    NET_CONN=$(netstat -ant | grep -c ESTABLISHED)

    # Prepare JSON data
    echo "{
        \"cpu\": $CPU,
        \"memory\": {
            \"total_mb\": $MEM_TOTAL,
            \"used_mb\": $MEM_USED
        },
        \"network_connections\": $NET_CONN,
        \"disk\": {"
    
    # Add disk information
    first=true
    while read -r line; do
        disk=($line)
        [ "$first" = false ] && echo ","
        first=false
        echo "            \"${disk[0]}\": ${disk[1]}"
    done <<< "$DISK_USAGE"
    
    echo "        }
    }"
}

# Generate output
case $OUTPUT_FORMAT in
    "json")
        OUTPUT_FILE="$LOG_DIR/system_stats_$TIMESTAMP.json"
        get_metrics > "$OUTPUT_FILE"
        ;;
    "csv")
        OUTPUT_FILE="$LOG_DIR/system_stats_$TIMESTAMP.csv"
        DATA=$(get_metrics)
        echo "timestamp,cpu%,mem_total_mb,mem_used_mb,network_connections,disks" > "$OUTPUT_FILE"
        printf "%s,%.2f,%d,%d,%d," $(date +%s) \
            $(echo "$DATA" | jq -r '.cpu,.memory.total_mb,.memory.used_mb,.network_connections') \
            >> "$OUTPUT_FILE"
        echo "$DATA" | jq -r '.disk | to_entries | map("\(.key)=\(.value)%") | join(";")' \
            >> "$OUTPUT_FILE"
        ;;
    *)
        echo "Invalid format. Use json or csv" >&2
        exit 1
        ;;
esac

[ -s "$OUTPUT_FILE" ] && echo "Metrics saved to $OUTPUT_FILE" || echo "Failed to collect metrics" >&2
