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
$formatted = "Free Memory Increased By: {0:N2}%" -f $percentIncrease

Write-Host "`nMemory Before Clearing: $beforeFree KB"
Write-Host "Memory After Clearing : $afterFree KB"
Write-Host $formatted
