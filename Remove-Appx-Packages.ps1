$UWPAppstoRemove = @(
    "Microsoft.BingNews",
    "Microsoft.GamingApp",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.WindowsCommunicationsApps",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "MicrosoftTeams",
    "Microsoft.Windows.DevHome",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.People",
    "Microsoft.ScreenSketch",
    "microsoft.windowscommunicationsapps",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps"
)
    
$UWPAppstoLeave = @(
    "Microsoft.OutlookForWindows"
)
    
    
# Remove preinstalled Microsoft Store applications for all users and from the Windows image
foreach ($UWPApp in $UWPAppstoRemove) {
    Get-AppxPackage -Name $UWPApp -AllUsers | Remove-AppxPackage -AllUsers -verbose
    Get-AppXProvisionedPackage -Online | Where-Object DisplayName -eq $UWPApp | Remove-AppxProvisionedPackage -Online -verbose
}