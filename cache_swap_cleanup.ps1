LINUX SERVER:
#!/bin/bash

LOG_FILE="/var/log/cache_swap_cleanup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "===== [$TIMESTAMP] Starting cache and swap cleanup =====" | tee -a $LOG_FILE

echo "--- Memory BEFORE ---" | tee -a $LOG_FILE
free -m | tee -a $LOG_FILE

echo "--- Syncing file system ---"
sync

echo "--- Dropping caches ---"
echo 3 > /proc/sys/vm/drop_caches

echo "--- Restarting swap ---"
swapoff -a && swapon -a

echo "--- Memory AFTER ---" | tee -a $LOG_FILE
free -m | tee -a $LOG_FILE

echo "===== [$TIMESTAMP] Cleanup complete =====" | tee -a $LOG_FILE
WINDOWS SERVER:

Write-Host "Clearing Windows Update Cache..."
Clear-BCCache
Write-Host "Windows Update Cache Cleared"

Write-Host "Clearing DNS Cache..."
Clear-DnsClientCache
Write-Host "DNS Cache Cleared"

Write-Host "Restarting WMI Service..."
Restart-Service -Name winmgmt -Force
Write-Host "WMI Service Restarted"

$before = Get-WmiObject -Class Win32_OperatingSystem
$beforeFree = [int]$before.FreePhysicalMemory
$totalMem = [int]$before.TotalVisibleMemorySize

Start-Sleep -Seconds 5

$after = Get-WmiObject -Class Win32_OperatingSystem
$afterFree = [int]$after.FreePhysicalMemory

$percentIncrease = (($afterFree - $beforeFree) / $totalMem) * 100

Write-Host "`nMemory Before Clearing: $beforeFree KB"
Write-Host "Memory After Clearing : $afterFree KB"

$formatted = "Free Memory Increased By: {0:N2}%" -f $percentIncrease
