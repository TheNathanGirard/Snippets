# Define the registry path and value name
$registryPath = 'HKCU:\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$valueName = 'InprocServer32'
$valueData = ''

# Ensure all parent keys exist
$parentKey = Split-Path -Path $registryPath -Parent
if (-not (Test-Path $parentKey)) {
    New-Item -Path $parentKey -Force | Out-Null
}

# Create the InprocServer32 key if it doesn't exist
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

# Set the default value to empty string
Set-ItemProperty -Path $registryPath -Name '(default)' -Value $valueData -Force
