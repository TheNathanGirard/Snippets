[CmdletBinding()]
param (
    [Parameter()]
    [String[]]$ExcludedModules,
    [String[]]$IncludedModules,
    [switch]$SkipPublisherCheck,
    [switch]$SimulationMode
)

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Is-PowerShell7Plus {
    return $PSVersionTable.PSVersion.Major -ge 7
}

if ($SimulationMode) {
    Write-Host -ForegroundColor Yellow 'Simulation mode is ON, nothing will be installed / removed / updated'
}

Write-Host -ForegroundColor Cyan 'Get all PowerShell modules'

function Remove-OldPowerShellModules {
    param (
        [string]$ModuleName,
        [string]$GalleryVersion
    )
    
    try {
        $getInstalled = if (Is-PowerShell7Plus) { Get-InstalledPSResource } else { Get-InstalledModule }
        $uninstall = if (Is-PowerShell7Plus) { Uninstall-PSResource } else { Uninstall-Module }
        
        $oldVersions = $getInstalled -Name $ModuleName -ErrorAction Stop | Where-Object { $_.Version -ne $GalleryVersion }

        foreach ($oldVersion in $oldVersions) {
            Write-Host -ForegroundColor Cyan "$ModuleName - Uninstall previous version ($($oldVersion.Version))"
            if (-not($SimulationMode)) {
                Remove-Module $oldVersion.Name -ErrorAction SilentlyContinue
                $uninstall $oldVersion -Force -ErrorAction Stop
            }
        }
    }
    catch {
        Write-Warning "$ModuleName - $($_.Exception.Message)"
    }
}

$modules = if (Is-PowerShell7Plus) {
    Write-Host "This is PowerShell 7 or later"
    Get-PSResource | Where-Object { -not $IncludedModules -or $IncludedModules -contains $_.Name }
} else {
    Write-Host "This is PowerShell 5.1 or earlier"
    Get-InstalledModule | Where-Object { -not $IncludedModules -or $IncludedModules -contains $_.Name }
}

foreach ($module in $modules) {
    if ($ExcludedModules -contains $module.Name) {
        Write-Host -ForegroundColor Yellow "Module $module.Name is excluded from the update process"
        continue
    }

    $currentVersion = $null
    $getInstalled = if (Is-PowerShell7Plus) { Get-InstalledPSResource } else { Get-InstalledModule }

    try {
        $currentVersion = ($getInstalled -Name $module.Name -ErrorAction Stop).Version
    }
    catch {
        Write-Warning "$module.Name - $($_.Exception.Message)"
        continue
    }

    try {
        $findModule = if (Is-PowerShell7Plus) { Find-PSResource } else { Find-Module }
        $moduleGalleryInfo = $findModule -Name $module.Name -ErrorAction Stop
    }
    catch {
        Write-Warning "$module.Name not found in the PowerShell Gallery. $($_.Exception.Message)"
        continue
    }

    if ($null -eq $currentVersion) {
        Write-Host -ForegroundColor Cyan "$module.Name - Install from PowerShellGallery version $($moduleGalleryInfo.Version) - Release date: $($moduleGalleryInfo.PublishedDate)"
        if (-not($SimulationMode)) {
            try {
                $installModule = if (Is-PowerShell7Plus) { Install-PSResource } else { Install-Module }
                $installModule -Name $module.Name -Force -SkipPublisherCheck:$SkipPublisherCheck.IsPresent -ErrorAction Stop
            }
            catch {
                Write-Warning "$module.Name - $($_.Exception.Message)"
            }
        }
    }
    elseif ([version]$currentVersion -eq [version]$moduleGalleryInfo.Version) {
        Write-Host -ForegroundColor Green "$module.Name already in latest version: $currentVersion - Release date: $($moduleGalleryInfo.PublishedDate)"
    }
    elseif ([version]$currentVersion -lt [version]$moduleGalleryInfo.Version) {
        Write-Host -ForegroundColor Cyan "$module.Name - Update from PowerShellGallery version $currentVersion -> $($moduleGalleryInfo.Version) - Release date: $($moduleGalleryInfo.PublishedDate)"
        if (-not($SimulationMode)) {
            try {
                $updateModule = if (Is-PowerShell7Plus) { Update-PSResource } else { Update-Module }
                $updateModule -Name $module.Name -Force -ErrorAction Stop
                Remove-OldPowerShellModules -ModuleName $module.Name -GalleryVersion $moduleGalleryInfo.Version
            }
            catch {
                HandleAuthenticodeWarning -module $module.Name -moduleGalleryInfo $moduleGalleryInfo
            }
        }
    }
}

function HandleAuthenticodeWarning {
    param (
        [string]$module,
        [object]$moduleGalleryInfo
    )

    if ($_.Exception.Message -match 'Authenticode') {
        Write-Host -ForegroundColor Yellow "$module - The module certificate used by the creator is either changed since the last module install or the module sign status has changed."
        if ($SkipPublisherCheck.IsPresent) {
            Write-Host -ForegroundColor Cyan "$module - SkipPublisherCheck Parameter is present, so install will run without Authenticode check"
            Write-Host -ForegroundColor Cyan "$module - Install from PowerShellGallery version $($moduleGalleryInfo.Version) - Release date: $($moduleGalleryInfo.PublishedDate)"  
            try {
                $installModule = if (Is-PowerShell7Plus) { Install-PSResource } else { Install-Module }
                $installModule -Name $module -Force -SkipPublisherCheck
                Remove-OldPowerShellModules -ModuleName $module -GalleryVersion $moduleGalleryInfo.Version
            }
            catch {
                Write-Warning "$module - $($_.Exception.Message)"
            }
        }
        else {
            Write-Warning "$module - If you want to update this module, run again with -SkipPublisherCheck switch, but please keep in mind the security risk"
        }
    }
    else {
        Write-Warning "$module - $($_.Exception.Message)"
    }
}