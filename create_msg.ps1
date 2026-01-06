# ============================
# Create initial Slack dashboard message
# ============================

$BaseDir = $PSScriptRoot
$ConfigFile = Join-Path $BaseDir "config.ps1"
$TSFile     = Join-Path $BaseDir "message_ts.txt"

if (!(Test-Path $ConfigFile)) {
    Write-Error "Config file not found: $ConfigFile"
    exit 1
}

# Load config
. $ConfigFile

# Post initial message
$InitialText = "Initializing dashboard for $PC_NAME..."

$Payload = @{
    channel = $SLACK_CHANNEL_ID
    text    = $InitialText
} | ConvertTo-Json -Depth 4

$response = Invoke-RestMethod `
    -Uri "https://slack.com/api/chat.postMessage" `
    -Method Post `
    -Headers @{ Authorization = "Bearer $SLACK_BOT_TOKEN" } `
    -ContentType "application/json; charset=utf-8" `
    -Body $Payload

if ($response.ok -eq $true) {
    $TS = $response.ts
    Write-Host "Dashboard message created successfully."
    Write-Host "Message ts: $TS"

    # Save ts to file
    Set-Content -Path $TSFile -Value $TS -Encoding UTF8

    Write-Host ""
    Write-Host "Press any key to continue to dashboard loop..."
    [void][System.Console]::ReadKey($true)
} else {
    Write-Error "Failed to create dashboard message: $($response.error)"
}
