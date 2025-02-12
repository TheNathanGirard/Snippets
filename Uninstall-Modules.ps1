[CmdletBinding()]
param (
    [Parameter()]
    # To exclude modules from the update process
    [String[]]$ExcludedModules,
    # To include only these modules for the update process
    [String[]]$IncludedModules,
    [switch]$SimulationMode
)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if ($SimulationMode) {
    Write-Host -ForegroundColor yellow 'Simulation mode is ON, nothing will be installed / removed / updated'
}

Write-Host -ForegroundColor Cyan 'Get all PowerShell modules'

if ($IncludedModules) {
    # $modules = Get-InstalledModule | Where-Object { $IncludedModules -contains $_.Name }
    $modules = Get-InstalledModule | Where-Object -Property Name -Like $IncludedModules
}
else {
    $modules = Get-InstalledModule
}

foreach ($module in $modules.Name) {
    Write-Host -ForegroundColor Cyan "Uninstalling module $module"
    if (-not($SimulationMode)) {
        Remove-Module $module -ErrorAction SilentlyContinue
        Uninstall-Module $module -AllVersions -Force  -ErrorAction Stop
    }
}

