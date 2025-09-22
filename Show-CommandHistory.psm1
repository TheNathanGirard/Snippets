function Show-CommandHistory {
    <#
    .SYNOPSIS
        Displays PowerShell command history from current and previous sessions.
    .DESCRIPTION
        Combines Get-History (current session, with timestamps)
        and the persisted PSReadLine history file (no timestamps).
    .PARAMETER Count
        Number of most recent history entries to show. Defaults to all available.
    .EXAMPLE
        Show-CommandHistory
        # Displays all current and past session commands with timestamps if available.
    .EXAMPLE
        Show-CommandHistory -Count 20
        # Displays the last 20 commands across sessions.
    #>
    param (
        [int]$Count
    )

    $historyFile = Join-Path $env:APPDATA "Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"

    # Past session history (no timestamps available)
    $fileHistory = if (Test-Path $historyFile) {
        Get-Content $historyFile -ErrorAction SilentlyContinue | ForEach-Object {
            [PSCustomObject]@{
                Time     = 'N/A'
                Command  = $_
                Source   = 'Previous Session'
            }
        }
    } else { @() }

    # Current session history (with timestamps)
    $sessionHistory = Get-History | ForEach-Object {
        [PSCustomObject]@{
            Time     = $_.StartExecutionTime
            Command  = $_.CommandLine
            Source   = 'Current Session'
        }
    }

    # Combine both
    $allHistory = $fileHistory + $sessionHistory

    if ($Count -gt 0) {
        $allHistory | Select-Object -Last $Count | Format-Table Time, Command, Source -AutoSize
    } else {
        $allHistory | Format-Table Time, Command, Source -AutoSize
    }
}
