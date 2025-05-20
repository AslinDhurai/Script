# Delete files >90 days old, excluding system paths
# First create cleanup_test directory in Disk C:
$targetDir = "C:\cleanup_test"
$logFile = "C:\logs\cleanup_$(Get-Date -Format yyyyMMdd).log"

$excludedPaths = @(
    "C:\Windows\*",
    "C:\Program Files\*",
    "C:\Program Files (x86)\*"
)

Get-ChildItem $targetDir -Recurse -File | 
Where-Object {
    $_.LastWriteTime -lt (Get-Date).AddDays(-90) -and
    ($excludedPaths -notcontains $_.DirectoryName)
} | ForEach-Object {
    Write-Output "Deleted: $($_.FullName)"
    Remove-Item $_.FullName -Force
} | Out-File $logFile -Append
