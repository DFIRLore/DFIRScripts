#Quickly pull the date of the oldest Windows Security Log entry for DFIR triage
# Must be run as admin!
$logName = "Security"

try {
    # Verify the SEcurity log exists 
    $logInfo = Get-WinEvent -ListLog $logName -ErrorAction Stop

    if (-not $logInfo.IsEnabled) {
        Write-Host "Security log is disabled."
        return
    }

    if ($logInfo.RecordCount -eq 0) {
        Write-Host "Security log contains no events."
        return
    }

    # Get the earliest event using -MaxEvents 1 and sorting by TimeCreated
    $oldestEvent = Get-WinEvent -LogName $logName -MaxEvents 1 -Oldest -ErrorAction Stop

    if ($null -eq $oldestEvent) {
        Write-Host "No readable events in the Security log."
        return
    }

    # Write to screen
    [PSCustomObject]@{
        LogName          = $logName
        OldestRecordId   = $oldestEvent.RecordId
        OldestEventTime  = $oldestEvent.TimeCreated
        OldestEventUtc   = $oldestEvent.TimeCreated.ToUniversalTime()
    }
}
catch {
    Write-Error "Could not read Security log: $_"
}
