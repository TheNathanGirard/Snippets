<# 
.SYNOPSIS
  Summarize memory usage by process name.

.DESCRIPTION
  Groups running processes by Name and shows the total memory used by all
  instances of each process. Sorts by total memory descending.

.PARAMETER Metric
  Which memory metric to use:
    - WorkingSet       (default) Physical memory in use
    - PrivateMemory    Private bytes
    - PagedMemory      Paged memory size
    - VirtualMemory    Virtual memory size

.EXAMPLE
  .\Get-ProcessMemorySummary.ps1
  # Uses WorkingSet (physical) and shows totals by process name.

.EXAMPLE
  .\Get-ProcessMemorySummary.ps1 -Metric PrivateMemory
#>

[CmdletBinding()]
param(
    [ValidateSet('WorkingSet','PrivateMemory','PagedMemory','VirtualMemory')]
    [string]$Metric = 'WorkingSet'
)

# Map friendly metric names to actual Get-Process properties
$metricMap = @{
    WorkingSet   = 'WorkingSet64'
    PrivateMemory= 'PrivateMemorySize64'
    PagedMemory  = 'PagedMemorySize64'
    VirtualMemory= 'VirtualMemorySize64'
}

$prop = $metricMap[$Metric]

# Get processes and handle access errors quietly
$processes = Get-Process -ErrorAction SilentlyContinue

# Group by Name and compute totals
$summary =
    $processes |
    Group-Object Name |
    ForEach-Object {
        $sumBytes = ($_.Group | Measure-Object -Property $prop -Sum).Sum
        # Some processes can report $null for a metric; coalesce to 0
        if ($null -eq $sumBytes) { $sumBytes = 0 }

        [pscustomobject]@{
            ProcessName       = $_.Name
            Instances         = $_.Count
            TotalMemoryBytes  = [int64]$sumBytes
            TotalMemoryMB     = [math]::Round($sumBytes / 1MB, 2)
        }
    } |
    Sort-Object TotalMemoryBytes -Descending

# Output nicely formatted table by default
$summary | Select-Object ProcessName, Instances, TotalMemoryMB | Format-Table -AutoSize

# Also return the raw objects if the script is dot-sourced or captured
$summary
