# ============================
# RDP State Debug Script
# ============================

Write-Host "RDP State Monitor"
Write-Host "Connect / disconnect RDP to this machine to test."
Write-Host "Press any key to exit."
Write-Host "--------------------------------------------"

$LastEventRecordId = $null

while (-not [Console]::KeyAvailable) {

    try {
        $Event = Get-WinEvent `
            -LogName "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" `
            -MaxEvents 1

        if ($Event.RecordId -ne $LastEventRecordId) {
            $LastEventRecordId = $Event.RecordId

            Write-Host ""
            Write-Host "Event Time : $($Event.TimeCreated)"
            Write-Host "Event ID   : $($Event.Id)"
            Write-Host "User       : $($Event.Properties[0].Value)"

            switch ($Event.Id) {
                21 { Write-Host "RDP State  : CONNECTED" -ForegroundColor Green }
                24 { Write-Host "RDP State  : DISCONNECTED" -ForegroundColor Yellow }
                default {
                    Write-Host "RDP State  : Other event ($($Event.Id))"
                }
            }

            Write-Host "--------------------------------------------"
        }
    } catch {
        Write-Host "Error reading RDP event log: $_" -ForegroundColor Red
    }

    Start-Sleep -Seconds 1
}

# Clear the buffered key
[Console]::ReadKey($true) | Out-Null
Write-Host "`nExiting RDP test."
