# Ensure the script can run with elevated privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as an Administrator!"
    break
}

# Disable Start Menu Web Search via Registry
$registryPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
$propertyName = "DisableSearchBoxSuggestions"
$propertyValue = 1

# Create the key if it doesn't exist
if (-not (Test-Path $registryPath)) {
    # Write-Host "No path"
    try {
        New-Item -Path $registryPath -Force
    }
    catch {
        Write-Error "Failed to create registry path: $registryPath. Please run this script with administrative privileges."
        exit 1
    }
    
}

# Set the registry value

try {
    New-ItemProperty -Path $registryPath -Name $propertyName -Value $propertyValue -PropertyType DWORD -Force
    Write-Output "Web search in Start menu has been disabled. Please restart your computer or log off and back on for changes to take effect."
}
catch {
    Write-Error "Failed to set registry value: $propertyName. Please run this script with administrative privileges."
    exit 1
}


