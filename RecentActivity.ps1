<#Recent Activity v1.0
1/10/2026
Camille Lore

Parses recent activity report for Windows 10/11 using UserAssist (recent programs) and Jump Lists (recent files)
    parsing:
    - Last Used timestamp
    - Run count (programs)
    - User 
    - Auto-exports to CSV in the script folder
#>

# ROT13 decode
function Decode-Rot13 {
    param([string]$InputString)
    $chars = $InputString.ToCharArray() | ForEach-Object {
        $c = [int][char]$_
        if ($c -ge 65 -and $c -le 90) { [char]((($c-65+13)%26)+65) }
        elseif ($c -ge 97 -and $c -le 122) { [char]((($c-97+13)%26)+97) }
        else { [char]$c }
    }
    return ($chars -join '')
}

# Parse UserAssist (recent programs)
function Get-RecentPrograms {
    $userAssistPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
    $uas = Get-ChildItem $userAssistPath -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -eq 'Count' }

    $results = @()
    foreach ($ua in $uas) {
        $values = Get-ItemProperty $ua.PSPath
        foreach ($prop in $values.PSObject.Properties) {
            if ($prop.Name -notin "PSPath","PSParentPath","PSChildName") {
                $decodedName = Decode-Rot13 $prop.Name
                if ($decodedName -match "\\.*\.exe$") {
                    $val = $prop.Value
                    try { $lastRun = [DateTime]::FromFileTime($val.LastRunTime) } catch { $lastRun = $null }
                    if ($lastRun -and $lastRun -gt [datetime]'2000-01-01') {
                        $results += [PSCustomObject]@{
                            Type       = "Program"
                            Name       = [System.IO.Path]::GetFileName($decodedName)
                            Path       = $decodedName
                            RunCount   = $val.Count
                            LastUsed   = $lastRun
                            User       = $env:USERNAME
                        }
                    }
                }
            }
        }
    }
    return $results
}

# Parse Jump Lists (recent files)
function Get-RecentFiles {
    $recentPath = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
    $results = @()

    if (Test-Path $recentPath) {
        Get-ChildItem $recentPath -File | ForEach-Object {
            try {
                $bytes = [IO.File]::ReadAllBytes($_.FullName)
                $str = [System.Text.Encoding]::Unicode.GetString($bytes)

                # Match strings that look like valid file paths with common extensions
                $matches = [regex]::Matches($str, "[A-Z]:\\[^\0]+?\.(txt|docx|xlsx|pptx|pdf|exe|lnk|bat|ps1|xml|json|csv)", "IgnoreCase")

                foreach ($m in $matches | Select-Object -Unique) {
                    $mClean = $m.Value.Trim([char]0)
                    if ($mClean -match "^[a-zA-Z]:\\") {
                        try {
                            if (Test-Path $mClean) {
                                $fileInfo = Get-Item $mClean -ErrorAction SilentlyContinue
                                if ($fileInfo) {
                                    $results += [PSCustomObject]@{
                                        Type       = "File"
                                        Name       = $fileInfo.Name
                                        Path       = $fileInfo.FullName
                                        RunCount   = $null
                                        LastUsed   = $fileInfo.LastAccessTime
                                        User       = (Get-Acl $fileInfo.FullName).Owner
                                    }
                                }
                            }
                        } catch { }
                    }
                }
            } catch { }
        }
    }
    return $results
}

# Pull data
$recentPrograms = Get-RecentPrograms
$recentFiles    = Get-RecentFiles

# Parse
$recentAll = $recentPrograms + $recentFiles

$recentAllClean = $recentAll | Where-Object { $_.LastUsed } |
    Sort-Object LastUsed -Descending

# Check running folder
$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptFolder) { $scriptFolder = Get-Location }

# Export CSV to folder
$exportPath = Join-Path $scriptFolder "RecentActivity.csv"
$recentAllClean | Select-Object Type, Name, Path, RunCount, LastUsed, User |
    Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8

Write-Host "Recent activity report exported to: $exportPath"

# Optional: Display top 50 entries in console
$recentAllClean | Select-Object -First 50 |
    Format-Table Type, Name, Path, RunCount, LastUsed, User -AutoSize
