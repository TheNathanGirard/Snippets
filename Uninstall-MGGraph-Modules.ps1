#Uninstall Microsoft.Graph modules except Microsoft.Graph.Authentication
$Modules = Get-Module Microsoft.Graph* -ListAvailable |
Where-Object $_.Name -ne "Microsoft.Graph.Authentication" | Select-Object Name -Unique
Foreach ($Module in $Modules)
$ModuleName = $Module.Name
$Versions = Get-Module $ModuleName -ListAvailable
Foreach ($Version in $Versions)
$ModuleVersion = $Version.Version
Write-Host "Uninstall-Module $ModuleName $ModuleVersion"
Uninstall-Module $ModuleName -RequiredVersion $ModuleVersion -ErrorAction SilentlyContinue
