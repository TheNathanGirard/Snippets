# List all known Wi-Fi profiles
$profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object {
    ($_ -split ":")[1].Trim()
}

# Define patterns to match for removal
$patternsToRemove = @("GL-*", "tasmota*", "shelly*", "ITEAD*")

# Loop through each profile and remove ones matching the specified patterns
foreach ($profile in $profiles) {
    foreach ($pattern in $patternsToRemove) {
        if ($profile -like $pattern) {
            Write-Host "Removing Wi-Fi profile: $profile"
            netsh wlan delete profile name="$profile"
            break
        }
    }
}

Write-Host "Cleanup complete."
