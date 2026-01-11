<#Scheduled Tasks v1.0
1/10/2026
Camille Lore

Lists all scheduled tasks, including: creation and last modified filters, executables, timestamps, and exports to CSV

.DESCRIPTION
Lists all scheduled tasks on the host, including:
- TaskName, Folder, State, LastRunTime, NextRunTime
- Author, Enabled, Description
- Executable(s)/Actions
- CreationTime and LastModifiedTime
Allows filtering by creation date (-Days) and/or last modified date (-ModifiedDays).

.PARAMETER Days
Optional. Number of days to filter tasks created in the last X days.

.PARAMETER ModifiedDays
Optional. Number of days to filter tasks modified in the last X days.

.PARAMETER Help
Displays script usage instructions.

.EXAMPLE
.\Get-AllScheduledTasks.ps1 -Days 7
# Lists tasks created in the last 7 days

.EXAMPLE
.\Get-AllScheduledTasks.ps1 -ModifiedDays 3
# Lists tasks modified in the last 3 days

.EXAMPLE
.\Get-AllScheduledTasks.ps1 -Days 7 -ModifiedDays 3
# Lists tasks created in last 7 days AND modified in last 3 days
#>

param(
    [int]$Days = 0,
    [int]$ModifiedDays = 0,
    [switch]$Help
)

function Show-Help {
    Write-Host "Scheduled Tasks Script" -ForegroundColor Cyan
    Write-Host "Usage:"
    Write-Host "  .\Get-AllScheduledTasks.ps1                          # List all scheduled tasks"
    Write-Host "  .\Get-AllScheduledTasks.ps1 -Days 7                  # Tasks created in last 7 days"
    Write-Host "  .\Get-AllScheduledTasks.ps1 -ModifiedDays 3          # Tasks modified in last 3 days"
    Write-Host "  .\Get-AllScheduledTasks.ps1 -Days 7 -ModifiedDays 3  # Created last 7 days AND modified last 3 days"
    Write-Host "  .\Get-AllScheduledTasks.ps1 -Help                    # Show this help"
}

if ($Help) { Show-Help; return }

$OutputCsv = "$PSScriptRoot\ScheduledTasks.csv"
$tasks = @()

try {
    # Get all scheduled tasks 
    $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue

    foreach ($task in $allTasks) {
        try {
            $info = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue

            $lastRun = if ($info -and $info.LastRunTime) { $info.LastRunTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "Never" }
            $nextRun = if ($info -and $info.NextRunTime) { $info.NextRunTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }

            $actions = if ($task.Actions) {
                ($task.Actions | ForEach-Object {
                    if ($_.Execute) { $_.Execute } elseif ($_.Command) { $_.Command } else { $_.Arguments }
                }) -join "; "
            } else { "" }

            # File system path
            $taskFile = Join-Path "C:\Windows\System32\Tasks" ($task.TaskPath.TrimStart("\") + "\" + $task.TaskName)
            if (Test-Path $taskFile) {
                $creationTime = (Get-Item $taskFile).CreationTime
                $lastModifiedTime = (Get-Item $taskFile).LastWriteTime
            } else {
                $creationTime = $null
                $lastModifiedTime = $null
            }

            # Apply creation date filter if specified
            if ($Days -gt 0 -and $creationTime) {
                if ((Get-Date) - $creationTime -gt ([TimeSpan]::FromDays($Days))) { continue }
            }

            # Apply modified date filter if specified
            if ($ModifiedDays -gt 0 -and $lastModifiedTime) {
                if ((Get-Date) - $lastModifiedTime -gt ([TimeSpan]::FromDays($ModifiedDays))) { continue }
            }

            # Add to results
            $tasks += [PSCustomObject]@{
                TaskName         = $task.TaskName
                Folder           = $task.TaskPath
                State            = if ($info) { $info.State } else { "Unknown" }
                LastRunTime      = $lastRun
                NextRunTime      = $nextRun
                Author           = $task.Author
                Enabled          = $task.Enabled
                Description      = $task.Description
                Executable       = $actions
                CreationTime     = if ($creationTime) { $creationTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
                LastModifiedTime = if ($lastModifiedTime) { $lastModifiedTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "Unknown" }
            }
        }
        catch { continue }  # skip unreadable tasks
    }
}
catch {
    Write-Error "Failed to enumerate scheduled tasks: $_"
}

# Output
if ($tasks.Count -gt 0) {
    $tasks | Sort-Object Folder, TaskName | Format-Table -AutoSize
    $tasks | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Scheduled tasks exported to $OutputCsv" -ForegroundColor Green
} else {
    Write-Host "No tasks found matching the filter."
}
