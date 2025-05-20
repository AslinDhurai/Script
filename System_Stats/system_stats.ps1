#Requires -Version 5.1

param(
    [string]$OutputFormat = "json"  # json or csv
)

$LOG_DIR = "C:\SystemStatsLogs"
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"

# Create log directory if not exists
if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR | Out-Null
}

function Get-SystemMetrics {
    # CPU Usage (%)
    $CPU = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue

    # Memory Usage (MB)
    $MEM = Get-Counter '\Memory\Available MBytes'
    $MEM_TOTAL = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
    $MEM_USED = $MEM_TOTAL - $MEM.CounterSamples.CookedValue

    # Disk Usage (%)
    $DISKS = Get-Volume | Where-Object DriveType -eq 'Fixed' | Select-Object DriveLetter,
        @{Name="SizeGB";Expression={[math]::Round($_.Size / 1GB,2)}},
        @{Name="FreeGB";Expression={[math]::Round($_.SizeRemaining / 1GB,2)}},
        @{Name="Usage";Expression={[math]::Round(($_.Size - $_.SizeRemaining)/$_.Size * 100,2)}}

    # Network Connections
    $NET_CONN = (Get-NetTCPConnection | Where-Object State -eq 'Established').Count

    # Prepare data
    $DATA = [ordered]@{
        timestamp = [datetime]::Now.ToString("o")
        cpu = [math]::Round($CPU, 2)
        memory = @{
            total_mb = $MEM_TOTAL
            used_mb = [math]::Round($MEM_USED, 2)
        }
        network_connections = $NET_CONN
        disk = @{}
    }

    foreach ($disk in $DISKS) {
        if ($disk.DriveLetter) {
            $DATA.disk["$($disk.DriveLetter):"] = $disk.Usage
        }
    }

    return $DATA
}

# Generate output
$OUTPUT_FILE = "$LOG_DIR\system_stats_$TIMESTAMP.$OutputFormat"
$METRICS = Get-SystemMetrics

switch ($OutputFormat) {
    "json" {
        $METRICS | ConvertTo-Json -Depth 3 | Out-File $OUTPUT_FILE
    }
    "csv" {
        $CSV_HEADER = "timestamp,cpu%,mem_total_mb,mem_used_mb,network_connections,disks"
        $CSV_LINE = ("{0},{1},{2},{3},{4}," -f 
            $METRICS.timestamp,
            $METRICS.cpu,
            $METRICS.memory.total_mb,
            $METRICS.memory.used_mb,
            $METRICS.network_connections)
        
        $DISK_ENTRIES = foreach ($disk in $METRICS.disk.GetEnumerator()) {
            "{0}={1}%" -f $disk.Key, $disk.Value
        }
        $CSV_LINE += ($DISK_ENTRIES -join ';')
        
        $CSV_HEADER + "`n" + $CSV_LINE | Out-File $OUTPUT_FILE -Encoding UTF8
    }
    default {
        Write-Host "Invalid format. Use json or csv"
        exit 1
    }
}

# Validate output
if (Test-Path $OUTPUT_FILE -PathType Leaf) {
    Write-Host "Metrics collected successfully: $OUTPUT_FILE"
    exit 0
} else {
    Write-Host "Failed to collect metrics"
    exit 1
}
