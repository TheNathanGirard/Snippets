$strArray = @(
    "powershell-core", 
    "microsoft-windows-terminal",
    "bitwarden", 
    "7zip",
    "python",
    "googlechrome",
    "notepadplusplus",
    "vscode",
    "firefox",
    "sonos-controller",
    "spotify",
    "wireguard",
    "windirstat",
    "royalts-v6",
    "etcher",
    "sysinternals"
)

$testchoco = powershell choco -v
if (-not($testchoco)) {
    Write-Host "Seems Chocolatey is not installed, installing now" -ForegroundColor Red
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}
else {
    Write-Host "Chocolatey Version $testchoco is already installed.  Check for upgrade(s)" -ForegroundColor Green
    choco upgrade chocolatey -y
}

$installed_choco_apps = choco list --localonly

#Iterate through application array
ForEach ($strAppName in $strArray) {
    if ($installed_choco_apps -like "*$strAppName*") {
        Write-Host $strAppName "is already installed." -ForegroundColor Green
        # C:\ProgramData\chocolatey\choco.exe upgrade $strAppName
    }
    Else {
        Write-Host $strAppName "is NOT installed. Starting the installation" -ForegroundColor Red
        C:\ProgramData\chocolatey\choco.exe install $strAppName -y
    }
    # choco install $str -y
}

if ($installed_choco_apps -like "*git*") {
    Write-Host "Git is already installed." -ForegroundColor Green
    # C:\ProgramData\chocolatey\choco.exe upgrade $strAppName
}
Else {
    Write-Host "Git is NOT installed. Starting the installation" -ForegroundColor Red
    C:\ProgramData\chocolatey\choco.exe install git.install --params "/GitAndUnixToolsOnPath /WindowsTerminal /NoAutoCrlf -y
}
