# ============================
# RDP Status Dashboard Script
# ============================

$BaseDir   = $PSScriptRoot
$ConfigFile = Join-Path $BaseDir "config.ps1"
$StateFile  = Join-Path $BaseDir "state.json"

if (!(Test-Path $ConfigFile)) {
    Write-Error "Config file not found: $ConfigFile"
    exit 1
}

# Load config
. $ConfigFile

# ----------------------------
# Load or initialize state
# ----------------------------
if (Test-Path $StateFile) {
    $State = Get-Content $StateFile | ConvertFrom-Json
} else {
    $State = @{
        LastBoot        = ""
        RDPState        = "Unknown"
        LastRDPRecordId = 0
    }
}

# ----------------------------
# Local IPs (selected adapters)
# ----------------------------
$LocalIPText = "None"

if ($SHOW_LOCAL_IPS -and $IP_ADAPTERS) {
    $LocalIPs = @()
    foreach ($adapter in $IP_ADAPTERS) {
        $ips = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $adapter |
               Where-Object { $_.IPAddress -notlike "169.254*" } |
               Select-Object -ExpandProperty IPAddress
        if ($ips) { $LocalIPs += $ips }
    }
    $LocalIPText = if ($LocalIPs) { $LocalIPs -join ", " } else { "None" }
}

# ----------------------------
# Uptime / reboot detection
# ----------------------------
$OS = Get-CimInstance Win32_OperatingSystem
$LastBoot = $OS.LastBootUpTime
$Uptime   = (Get-Date) - $LastBoot

$RebootDetected = $false
if ($State.LastBoot -ne $LastBoot.ToString()) {
    $RebootDetected = $true
    $State.LastBoot = $LastBoot.ToString()
}

# ----------------------------
# RDP tracking (PROVEN METHOD)
# ----------------------------
$RDPStatus = $State.RDPState

if ($TRACK_RDP) {
    try {
        $Event = Get-WinEvent `
            -LogName "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" `
            -MaxEvents 1

        if ($Event.RecordId -ne $State.LastRDPRecordId) {
            $State.LastRDPRecordId = $Event.RecordId

            switch ($Event.Id) {
                25 { $RDPStatus = "In Use :red_circle:" }
                24 { $RDPStatus = "Available :green_circle:" }
            }

            $State.RDPState = $RDPStatus
        }
    } catch {
        $RDPStatus = "Error :large_yellow_circle:"
    }
}

# ----------------------------
# Save state
# ----------------------------
$State | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8

# ----------------------------
# Build Slack message
# ----------------------------
$Lines = @()
$Lines += ("*:desktop_computer: {0}*" -f $PC_NAME)
$Lines += ""
$Lines += ("*Local IP(s):* {0}" -f $LocalIPText)
$Lines += ""
$Lines += ("*Uptime:* {0}h {1}m" -f [int]$Uptime.TotalHours, $Uptime.Minutes)
$Lines += ("*Last Boot:* {0}" -f (Get-Date $LastBoot -Format "yyyy-MM-dd HH:mm:ss"))
$Lines += ""
$Lines += ("*RDP:* {0}" -f $RDPStatus)
$Lines += ("*Reboot Detected:* {0}" -f ($(if ($RebootDetected) { "YES" } else { "No" })))
$Lines += ""
$Lines += ("*Last Update:* {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))

$Text = $Lines -join "`n"

# ----------------------------
# Update Slack dashboard message
# ----------------------------
$Payload = @{
    channel = $SLACK_CHANNEL_ID
    ts      = $SLACK_MESSAGE_TS
    text    = $Text
} | ConvertTo-Json -Depth 4

Invoke-RestMethod `
    -Uri "https://slack.com/api/chat.update" `
    -Method Post `
    -Headers @{ Authorization = "Bearer $SLACK_BOT_TOKEN" } `
    -ContentType "application/json; charset=utf-8" `
    -Body $Payload
