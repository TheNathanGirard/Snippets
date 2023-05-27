[cmdletbinding()]
[outputtype("moduleInfo")]
Param(
   [Parameter(Position = 0, HelpMessage = "Enter a module name or names. Wildcards are allowed.")]
   [ValidateNotNullorEmpty()]
   [string[]]$Name = "*"
)

Write-Verbose "Getting installed modules"
Try {
   $modules = Get-Module -Name $name -ListAvailable -ErrorAction Stop
}
Catch {
   Throw $_
}

if ($modules) {
   Write-Verbose "Found $($modules.count) matching modules"
   #group to identify modules with multiple versions installed
   Write-Verbose "Grouping modules"
   $g = $modules | Group-Object name -NoElement | Where-Object count -GT 1

   Write-Verbose "Filter to modules from the PSGallery"
   $gallery = $modules.where( { $_.repositorysourcelocation })

   Write-Verbose "Comparing to online versions"
   foreach ($module in $gallery) {

      #find the current version in the gallery
      Try {
         Write-Verbose "Looking online for $($module.name)"
         $online = Find-Module -Name $module.name -Repository PSGallery -ErrorAction Stop
         #compare versions
         if (($online.version -as [version]) -gt ($module.version -as [version])) {
            $UpdateAvailable = $True
         }
         else {
            $UpdateAvailable = $False
         }

         #write a custom object to the pipeline
         [pscustomobject]@{
            PSTypeName       = "moduleInfo"
            Name             = $module.name
            MultipleVersions = ($g.name -contains $module.name)
            InstalledVersion = $module.version
            OnlineVersion    = $online.version
            Update           = $UpdateAvailable
            Path             = $module.modulebase
         }
      }
      Catch {
         Write-Warning "Module $($module.name) was not found in the PSGallery"
      }

   } #foreach
}
else {
   Write-Warning "No matching modules found."
}

Write-Verbose "Check complete"