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
    $version = $PSVersionTable.PSVersion
    return ($version.Major -ge 7)
}



if ($SimulationMode) {
    Write-Host -ForegroundColor yellow 'Simulation mode is ON, nothing will be installed / removed / updated'
}

Write-Host -ForegroundColor Cyan 'Get all PowerShell modules'

function Remove-OldPowerShellModules {
    param (
        [string]$ModuleName,
        [string]$GalleryVersion
    )
    
    try {
        if (Is-PowerShell7Plus) {
            $oldVersions = Get-InstalledPSResource -Name $ModuleName -ErrorAction Stop | Where-Object { $_.Version -ne $GalleryVersion }
        }
        else {
            $oldVersions = Get-InstalledModule -Name $ModuleName -AllVersions -ErrorAction Stop | Where-Object { $_.Version -ne $GalleryVersion }
        }

        foreach ($oldVersion in $oldVersions) {
            Write-Host -ForegroundColor Cyan "$ModuleName - Uninstall previous version ($($oldVersion.Version))"
            if (-not($SimulationMode)) {

                if (Is-PowerShell7Plus) {
                    $ModuleName = $oldVersion.Name
                    Remove-Module $ModuleName -ErrorAction SilentlyContinue
                    Uninstall-PSResource $oldVersion -SkipDependencyCheck -ErrorAction Stop
                }
                else {
                    $ModuleName = $oldVersion.Name
                    Remove-Module $ModuleName -ErrorAction SilentlyContinue
                    Uninstall-Module $oldVersion -Force  -ErrorAction Stop
                }
            }
        }
    }
    catch {
        Write-Warning "$module - $($_.Exception.Message)"
    }
}

if (Is-PowerShell7Plus) {
    Write-Host "This is PowerShell 7 or later"
    if ($IncludedModules) {
        $modules = Get-PSResource | Where-Object { $IncludedModules -contains $_.Name }
    }
    else {
        $modules = Get-PSResource
    }
}
else {
    Write-Host "This is PowerShell 5.1 or earlier"
    if ($IncludedModules) {
        $modules = Get-InstalledModule | Where-Object { $IncludedModules -contains $_.Name }
    }
    else {
        $modules = Get-InstalledModule
    }
}


foreach ($module in $modules.Name) {
    if ($ExcludedModules -contains $module) {
        Write-Host -ForegroundColor Yellow "Module $module is excluded from the update process"
        continue
    }
    elseif ($module -like "$excludedModules") {
        Write-Host -ForegroundColor Yellow "Module $module is excluded from the update process (match $excludeModules)"
        continue
    }

    $currentVersion = $null
	
    # Get the current version of the module
    if (Is-PowerShell7Plus) {
        try {
            $currentVersion = (Get-InstalledPSResource -Name $module -ErrorAction Stop).Version
        }
        catch {
            Write-Warning "$module - $($_.Exception.Message)"
            continue
        }
    }
    else {
        try {
            $currentVersion = (Get-InstalledModule -Name $module -AllVersions -ErrorAction Stop).Version
        }
        catch {
            Write-Warning "$module - $($_.Exception.Message)"
            continue
        }
    }
    
    
    # Get the module information from the PowerShell Gallery
    try {
        if (Is-PowerShell7Plus) { 
            $moduleGalleryInfo = Find-PSResource -Name $module -ErrorAction Stop
        }
        else { 
            $moduleGalleryInfo = Find-Module -Name $module -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "$module not found in the PowerShell Gallery. $($_.Exception.Message)"
    }
	
    
    if ($null -eq $currentVersion) {
        Write-Host -ForegroundColor Cyan "$module - Install from PowerShellGallery version $($moduleGalleryInfo.Version) - Release date: $($moduleGalleryInfo.PublishedDate)"  
		
        if (-not($SimulationMode)) {
            if (Is-PowerShell7Plus) {
                try {
                    Install-PSResource -Name $module -ErrorAction Stop
                }
                catch {
                    Write-Warning "$module - $($_.Exception.Message)"
                }
            }
            else {
                try {
                    Install-Module -Name $module -Force -SkipPublisherCheck -ErrorAction Stop
                }
                catch {
                    Write-Warning "$module - $($_.Exception.Message)"
                }
            }


        }
    }
    elseif ($moduleGalleryInfo.Version -eq $currentVersion) {
        Write-Host -ForegroundColor Green "$module already in latest version: $currentVersion - Release date: $($moduleGalleryInfo.PublishedDate)"
    }
    elseif ($currentVersion.count -gt 1) {
        Write-Host -ForegroundColor Yellow "$module is installed in $($currentVersion.count) versions (versions: $($currentVersion -join ' | '))"
        Write-Host -ForegroundColor Cyan "$module - Uninstall previous $module version(s) below the latest version ($($moduleGalleryInfo.Version))"
        
        Remove-OldPowerShellModules -ModuleName $module -GalleryVersion $moduleGalleryInfo.Version

        if (Is-PowerShell7Plus) {
            # Check again the current Version as we uninstalled some old versions
            $currentVersion = (Get-InstalledPSResource -Name $module).Version
        }
        else {
            # Check again the current Version as we uninstalled some old versions
            $currentVersion = (Get-InstalledModule -Name $module).Version
        }

        if ($moduleGalleryInfo.Version -ne $currentVersion) {
            Write-Host -ForegroundColor Cyan "$module - Install from PowerShellGallery version $($moduleGalleryInfo.Version) - Release date: $($moduleGalleryInfo.PublishedDate)"  
            if (-not($SimulationMode)) {
                if (Is-PowerShell7Plus) {
                    try {
                        Install-PSResource -Name $module -ErrorAction Stop

                        Remove-OldPowerShellModules -ModuleName $module -GalleryVersion $moduleGalleryInfo.Version
                    }
                    catch {
                        Write-Warning "$module - $($_.Exception.Message)"
                    }
                }
                else {
                    # PowerShell 5.1 or earlier
                    try {
                        Install-Module -Name $module -Force -ErrorAction Stop

                        Remove-OldPowerShellModules -ModuleName $module -GalleryVersion $moduleGalleryInfo.Version
                    }
                    catch {
                        Write-Warning "$module - $($_.Exception.Message)"
                    }
                }
                # try {
                #     Install-Module -Name $module -Force -ErrorAction Stop

                #     Remove-OldPowerShellModules -ModuleName $module -GalleryVersion $moduleGalleryInfo.Version
                # }
                # catch {
                #     Write-Warning "$module - $($_.Exception.Message)"
                # }
            }
        }
    }
    elseif ([version]$currentVersion -gt [version]$moduleGalleryInfo.Version) {   
        Write-Host -ForegroundColor Yellow "$module - the current version $currentVersion is newer than the version available on PowerShell Gallery $($moduleGalleryInfo.Version) (Release date: $($moduleGalleryInfo.PublishedDate)). Sometimes happens when you install a module from another repository or via .exe/.msi or if you change the version number manually."
    }
    elseif ([version]$currentVersion -lt [version]$moduleGalleryInfo.Version) {
        Write-Host -ForegroundColor Cyan "$module - Update from PowerShellGallery version " -NoNewline
        Write-Host -ForegroundColor White "$currentVersion -> $($moduleGalleryInfo.Version) " -NoNewline 
        Write-Host -ForegroundColor Cyan "- Release date: $($moduleGalleryInfo.PublishedDate)"
        
        if (-not($SimulationMode)) {
            try {
                if (Is-PowerShell7Plus) {
                    Update-PSResource -Name $module -ErrorAction Stop
                    Remove-OldPowerShellModules -ModuleName $module -GalleryVersion $moduleGalleryInfo.Version
                }
                else {
                    Update-Module -Name $module -Force -ErrorAction Stop
                    Remove-OldPowerShellModules -ModuleName $module -GalleryVersion $moduleGalleryInfo.Version
                }
            }
            catch {
                if ($_.Exception.Message -match 'Authenticode') {
                    Write-Host -ForegroundColor Yellow "$module - The module certificate used by the creator is either changed since the last module install or the module sign status has changed." 
                
                    if ($SkipPublisherCheck.IsPresent) {
                        Write-Host -ForegroundColor Cyan "$module - SkipPublisherCheck Parameter is present, so install will run without Authenticode check"
                        Write-Host -ForegroundColor Cyan "$module - Install from PowerShellGallery version $($moduleGalleryInfo.Version) - Release date: $($moduleGalleryInfo.PublishedDate)"  
                        try {
                            if (Is-PowerShell7Plus) {
                                Install-PSResource -Name $module
                            }
                            else {
                                # PowerShell 5.1 or earlier
                                Install-Module -Name $module -Force -SkipPublisherCheck
                            }
                        }
                        catch {
                            Write-Warning "$module - $($_.Exception.Message)"
                        }
                    
                        Remove-OldPowerShellModules -ModuleName $module -GalleryVersion $moduleGalleryInfo.Version
                    }
                    else {
                        Write-Warning "$module - If you want to update this module, run again with -SkipPublisherCheck switch, but please keep in mind the security risk"
                    }
                }
                else {
                    Write-Warning "$module - $($_.Exception.Message)"
                }
            }
        }
    }
}
