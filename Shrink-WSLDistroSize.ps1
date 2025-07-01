# Check for administrative privileges
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator."
    Exit 1
}


# List WSL2 Distributions and VHDX Sizes

function Get-HumanReadableSize {
    param ([int64]$Bytes)
    switch ($Bytes) {
        { $_ -ge 1PB } { return "{0:N2} PB" -f ($Bytes / 1PB) }
        { $_ -ge 1TB } { return "{0:N2} TB" -f ($Bytes / 1TB) }
        { $_ -ge 1GB } { return "{0:N2} GB" -f ($Bytes / 1GB) }
        { $_ -ge 1MB } { return "{0:N2} MB" -f ($Bytes / 1MB) }
        { $_ -ge 1KB } { return "{0:N2} KB" -f ($Bytes / 1KB) }
        default { return "$Bytes Bytes" }
    }
}

# Define the path
# $basePath = Join-Path $env:LOCALAPPDATA 'Packages'
$basePath = $env:LOCALAPPDATA

# Get all .vhdx files recursively
$vhdxFiles = Get-ChildItem -Path $basePath -Recurse -Filter *.vhdx -ErrorAction SilentlyContinue
$originalSizeBytes = 0
$optimizedSizeBytes = 0

foreach ($file in $vhdxFiles) {
    if ($file.Name -notlike '*swap.vhdx') {
        $originalSizeBytes += $file.Length
        Write-Host "Processing: $($file.FullName) - Size: $(Get-HumanReadableSize $file.Length)"
        Optimize-VHD -Path $file.FullName -Mode Full
        $optimizedSizeBytes += (Get-Item $file.FullName).Length
        Write-Host "Optimized: $($file.FullName) - Size: $(Get-HumanReadableSize (Get-Item $file.FullName).Length)"
    }
}

Write-Host "Total Original Size: $(Get-HumanReadableSize $originalSizeBytes)"
Write-Host "Total Optimized Size: $(Get-HumanReadableSize $optimizedSizeBytes)"
