# C:\Scripts\DiskUsageAlert.ps1
$envFile = "C:\Scripts\.env"
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.+)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
}

# === Configuration ===
$smtpServer = $env:SMTP_SERVER
$smtpPort = [int]$env:SMTP_PORT
$from = $env:EMAIL_FROM
$to = $env:EMAIL_TO
$username = $env:SMTP_USERNAME
$password = $env:SMTP_PASSWORD

# Optional log path
$logPath = "C:\Scripts\disk_alert_log.txt"

# === Prepare credentials ===
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($username, $securePassword)


# === Start disk usage monitoring ===
Get-Volume | ForEach-Object {
    $volume = $_
    
    # Skip 0-size volumes (optical, placeholder, etc.)
    if ($volume.Size -gt 0) {
        $used = $volume.Size - $volume.SizeRemaining
        $usagePercent = [math]::Round(($used / $volume.Size) * 100, 2)

        $name = if ($volume.DriveLetter) { "$($volume.DriveLetter):" } else { $volume.FriendlyName }

        if ($usagePercent -gt 80) {
            $body = "ALERT: Drive $($volume.DriveLetter):`nUsage: $usagePercent%`nMount Point: $($volume.Path)"

            try {
                Send-MailMessage -From $from -To $to -Subject "ALERT: Disk Usage Exceeded" -Body $body `
                    -SmtpServer $smtpServer -Port $smtpPort -Credential $credentials -UseSsl -ErrorAction Stop

                Write-Output " Alert email sent for drive $($volume.DriveLetter):"
                Add-Content -Path $logPath -Value "[$(Get-Date)] ALERT: $body"
            } catch {
                Write-Output " ERROR sending alert email: $_"
                Add-Content -Path $logPath -Value "[$(Get-Date)]  ERROR sending alert email: $_"
            }
        } else {
            Add-Content -Path $logPath -Value "[$(Get-Date)] OK: Drive $($volume.DriveLetter): usage at $usagePercent%"
        }
    }
}
