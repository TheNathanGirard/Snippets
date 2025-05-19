# Clean-TempFiles.ps1

# Check for administrative privileges
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator."
    Exit 1
}

# Enable transcript for logging
$LogPath = "$env:ProgramData\TempCleanup\CleanupLog.txt"
$LogDir = Split-Path $LogPath
If (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

Start-Transcript -Path $LogPath -Append

Write-Host "Starting cleanup of temporary files..." -ForegroundColor Cyan

# Function to delete contents of a directory
function Remove-TempFilesFromPath {
    param(
        [string]$Path
    )
    if (Test-Path $Path) {
        try {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    if ($_.PSIsContainer) {
                        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    else {
                        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                    }
                }
                catch {
                    Write-Warning "Could not delete: $($_.FullName)"
                }
            }
            Write-Host "Cleaned: $Path"
        }
        catch {
            Write-Warning "Failed to clean: $Path"
        }
    }
    else {
        Write-Host "Path not found: $Path"
    }
}

# List of temp paths to clean
$tempPaths = @(
    "$env:TEMP",
    "$env:TMP",
    "$env:LOCALAPPDATA\Temp",
    "$env:WINDIR\Temp",
    "C:\Windows\Temp"
)

# Remove temp files
foreach ($path in $tempPaths) {
    Remove-TempFilesFromPath -Path $path
}

# End logging
Stop-Transcript

Write-Host "Temporary file cleanup completed." -ForegroundColor Green
