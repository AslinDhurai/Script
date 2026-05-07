#!/bin/bash

LOG_FILE="/var/log/cache_swap_cleanup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "===== [$TIMESTAMP] Starting cache and swap cleanup =====" | tee -a "$LOG_FILE"

echo "--- Memory BEFORE ---" | tee -a "$LOG_FILE"
free -m | tee -a "$LOG_FILE"

echo "--- Syncing file system ---"
sync

echo "--- Dropping caches ---"
echo 3 > /proc/sys/vm/drop_caches

echo "--- Restarting swap ---"
swapoff -a && swapon -a

echo "--- Memory AFTER ---" | tee -a "$LOG_FILE"
free -m | tee -a "$LOG_FILE"

echo "===== [$TIMESTAMP] Cleanup complete =====" | tee -a "$LOG_FILE"
