#!/bin/bash
# Delete files >90 days old, excluding critical paths
TARGET_DIR="/tmp/cleanup_test"
LOG_FILE="/home/poc-user/log/cleanup_$(date +%Y%m%d).log"

{
  echo "Starting cleanup at $(date)"
  find "$TARGET_DIR" \
    -type f \
    -mtime +90 \
    -not -path "/etc/*" \
    -not -path "/proc/*" \
    -not -path "/sys/*" \
    -delete \
    -printf "Deleted: %p\n"
  echo "Cleanup completed at $(date)"
} | tee -a "$LOG_FILE"
