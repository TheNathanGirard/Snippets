# List all known Wi-Fi profiles
$profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
    ($_ -split ":")[1].Trim()
}

# Loop through each profile and remove ones starting with "GL-"
foreach ($profile in $profiles) {
    # Write-Host $profile
    if ($profile -like "GL-*") {
        Write-Host "Removing Wi-Fi profile: $profile"
        netsh wlan delete profile name="$profile"
    }

    if ($profile -like "tasmota*") {
        Write-Host "Removing Wi-Fi profile: $profile"
        netsh wlan delete profile name="$profile"
    }

    if ($profile -like "shelly*") {
        Write-Host "Removing Wi-Fi profile: $profile"
        netsh wlan delete profile name="$profile"
    }
    
    if ($profile -like "ITEAD*") {
        Write-Host "Removing Wi-Fi profile: $profile"
        netsh wlan delete profile name="$profile"
    }

}

Write-Host "Cleanup complete."
