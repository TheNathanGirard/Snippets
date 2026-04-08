#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

<#
.SYNOPSIS
    Creates a new Hyper-V VHDX disk, applies a GPT/MBR partition layout, and deploys a WIM image.

.DESCRIPTION
    Automates the full disk preparation pipeline for Hyper-V VM disks:
      - Creates a new fixed or dynamic VHDX
      - Initializes and partitions the disk (GPT/UEFI or MBR/BIOS)
      - Formats and labels all required partitions
      - Applies a WIM image via DISM
      - Stamps the bootloader (BCDboot) for UEFI or BIOS boot

.PARAMETER VHDXPath
    Full path where the VHDX file will be created.
    Example: "C:\Hyper-V\VMs\MyVM\disk0.vhdx"

.PARAMETER WIMPath
    Full path to the source WIM or ESD file.
    Example: "D:\Sources\install.wim"

.PARAMETER WIMIndex
    Index of the image within the WIM to apply. Defaults to 1.

.PARAMETER DiskSizeGB
    Total size of the VHDX in gigabytes. Defaults to 60 GB.

.PARAMETER DiskType
    VHDX allocation type: Dynamic (thin-provisioned) or Fixed. Defaults to Dynamic.

.PARAMETER PartitionStyle
    Partition table type: GPT (UEFI, recommended) or MBR (legacy BIOS). Defaults to GPT.

.PARAMETER WindowsPartitionSizeGB
    Size of the Windows OS partition in GB. Defaults to 0 (uses all remaining space).

.PARAMETER RecoveryPartitionSizeMB
    Size of the WinRE recovery partition in MB. Defaults to 1024 MB. Set to 0 to skip.

.PARAMETER Force
    Overwrite an existing VHDX at the target path without prompting.

.EXAMPLE
    .\New-HyperVDisk.ps1 `
        -VHDXPath "C:\Hyper-V\VMs\Server2025\disk0.vhdx" `
        -WIMPath "D:\Sources\install.wim" `
        -WIMIndex 2 `
        -DiskSizeGB 80

.EXAMPLE
    # Legacy BIOS/MBR VM with a fixed disk
    .\New-HyperVDisk.ps1 `
        -VHDXPath "E:\VMs\LegacyVM\disk0.vhdx" `
        -WIMPath "D:\Sources\install.wim" `
        -DiskType Fixed `
        -PartitionStyle MBR `
        -DiskSizeGB 40

.NOTES
    - Must be run as Administrator.
    - Requires the Hyper-V PowerShell module (RSAT or Hyper-V role).
    - DISM.exe must be available (included with Windows ADK or the OS itself).
    - BCDboot.exe must be available on the host (standard with Windows 10/11/Server 2016+).
    - GPT layout creates: EFI System (100 MB), MSR (16 MB), Windows, Recovery (optional).
    - MBR layout creates: System Reserved (500 MB), Windows, Recovery (optional).
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory, HelpMessage = "Destination path for the new VHDX file.")]
    [ValidateScript({
        $parent = Split-Path $_ -Parent
        if (-not (Test-Path $parent)) {
            throw "Parent directory '$parent' does not exist. Create it first."
        }
        $true
    })]
    [string] $VHDXPath,

    [Parameter(Mandatory, HelpMessage = "Path to the source WIM or ESD image file.")]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) { throw "WIM file not found: $_" }
        $true
    })]
    [string] $WIMPath,

    [Parameter()]
    [ValidateRange(1, 99)]
    [int] $WIMIndex = 1,

    [Parameter()]
    [ValidateRange(20, 2048)]
    [int] $DiskSizeGB = 60,

    [Parameter()]
    [ValidateSet("Dynamic", "Fixed")]
    [string] $DiskType = "Dynamic",

    [Parameter()]
    [ValidateSet("GPT", "MBR")]
    [string] $PartitionStyle = "GPT",

    [Parameter()]
    [ValidateRange(0, 1900)]
    [int] $WindowsPartitionSizeGB = 0,

    [Parameter()]
    [ValidateRange(0, 4096)]
    [int] $RecoveryPartitionSizeMB = 1024,

    [Parameter()]
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Helpers ──────────────────────────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n[$([char]0x25BA)] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [--] $Message" -ForegroundColor Gray
}

function Invoke-DismCommand {
    param([string[]]$Arguments)
    $dismPath = "$env:SystemRoot\System32\dism.exe"
    if (-not (Test-Path $dismPath)) {
        throw "DISM.exe not found at '$dismPath'. Install the Windows ADK."
    }
    Write-Info "DISM: $($Arguments -join ' ')"
    & $dismPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "DISM failed with exit code $LASTEXITCODE."
    }
}

function Invoke-BcdbootCommand {
    param([string[]]$Arguments)
    $bcdPath = "$env:SystemRoot\System32\bcdboot.exe"
    if (-not (Test-Path $bcdPath)) {
        throw "BCDboot.exe not found at '$bcdPath'."
    }
    Write-Info "BCDboot: $($Arguments -join ' ')"
    & $bcdPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "BCDboot failed with exit code $LASTEXITCODE."
    }
}

function Get-UnusedDriveLetter {
    $used = (Get-PSDrive -PSProvider FileSystem).Name
    foreach ($letter in 'S','T','U','V','W','X','Y','Z') {
        if ($letter -notin $used) { return "${letter}:" }
    }
    throw "No unused drive letters available."
}

# ─── Pre-flight checks ────────────────────────────────────────────────────────

Write-Step "Pre-flight checks"

# Validate WIM index exists
Write-Info "Validating WIM index $WIMIndex in '$WIMPath'..."
$wimInfo = Get-WindowsImage -ImagePath $WIMPath | Where-Object { $_.ImageIndex -eq $WIMIndex }
if (-not $wimInfo) {
    $available = (Get-WindowsImage -ImagePath $WIMPath | Select-Object -ExpandProperty ImageIndex) -join ", "
    throw "WIM index $WIMIndex not found. Available indices: $available"
}
Write-Success "WIM index $WIMIndex found: '$($wimInfo.ImageName)'"

# Check for existing VHDX
if (Test-Path $VHDXPath) {
    if ($Force) {
        Write-Info "Removing existing VHDX at '$VHDXPath'..."
        Remove-Item -Path $VHDXPath -Force
    }
    else {
        throw "VHDX already exists at '$VHDXPath'. Use -Force to overwrite."
    }
}

# Sanity check partition sizes vs disk size
$diskSizeMB   = $DiskSizeGB * 1024
$requiredMB   = if ($PartitionStyle -eq "GPT") { 100 + 16 } else { 500 }  # EFI+MSR or SysReserved
$requiredMB  += if ($RecoveryPartitionSizeMB -gt 0) { $RecoveryPartitionSizeMB } else { 0 }
$requiredMB  += if ($WindowsPartitionSizeGB -gt 0) { $WindowsPartitionSizeGB * 1024 } else { 20 * 1024 } # min 20 GB Windows

if ($diskSizeMB -lt $requiredMB) {
    throw "Disk size ($diskSizeMB MB) is too small for the requested partition layout ($requiredMB MB minimum)."
}

Write-Success "Pre-flight checks passed."

# ─── Step 1: Create VHDX ──────────────────────────────────────────────────────

Write-Step "Creating $DiskType VHDX ($DiskSizeGB GB) at '$VHDXPath'"

$newVhdParams = @{
    Path      = $VHDXPath
    SizeBytes = [int64]$DiskSizeGB * 1GB
}
if ($DiskType -eq "Dynamic") {
    $newVhdParams["Dynamic"] = $true
}
else {
    $newVhdParams["Fixed"] = $true
}

New-VHD @newVhdParams | Out-Null
Write-Success "VHDX created."

# ─── Step 2: Mount VHDX ───────────────────────────────────────────────────────

Write-Step "Mounting VHDX"

Mount-VHD -Path $VHDXPath -NoDriveLetter
$disk = Get-Disk | Where-Object {
    $_.Location -like "*$([System.IO.Path]::GetFileName($VHDXPath))*" -or
    (Get-VHD -Path $VHDXPath).DiskNumber -eq $_.Number
}
# More reliable: get disk number from the VHD object directly
$diskNumber = (Get-VHD -Path $VHDXPath).DiskNumber
if ($null -eq $diskNumber) {
    throw "Could not determine disk number for mounted VHDX."
}
Write-Success "VHDX mounted as Disk $diskNumber."

# ─── Step 3: Initialize and partition the disk ────────────────────────────────

try {

    Write-Step "Initializing disk ($PartitionStyle)"
    Initialize-Disk -Number $diskNumber -PartitionStyle $PartitionStyle
    Write-Success "Disk initialized with $PartitionStyle partition table."

    # ── GPT / UEFI layout ─────────────────────────────────────────────────────
    if ($PartitionStyle -eq "GPT") {

        Write-Step "Creating GPT partitions (EFI + MSR + Windows$(if ($RecoveryPartitionSizeMB -gt 0) {' + Recovery'}))"

        # EFI System Partition (ESP) — 100 MB, FAT32
        Write-Info "Creating EFI System Partition (100 MB)..."
        $efiPart = New-Partition -DiskNumber $diskNumber `
                                 -Size 100MB `
                                 -GptType "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" # EFI System
        $efiLetter = Get-UnusedDriveLetter
        Add-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber $efiPart.PartitionNumber -AccessPath $efiLetter
        Format-Volume -DriveLetter $efiLetter.TrimEnd(':') -FileSystem FAT32 -NewFileSystemLabel "EFI" -Force | Out-Null
        Write-Success "EFI partition created at $efiLetter"

        # Microsoft Reserved Partition (MSR) — 16 MB, no filesystem
        Write-Info "Creating MSR (16 MB)..."
        New-Partition -DiskNumber $diskNumber `
                      -Size 16MB `
                      -GptType "{e3c9e316-0b5c-4db8-817d-f92df00215ae}" | Out-Null # MSR
        Write-Success "MSR partition created."

        # Recovery partition (optional) — placed BEFORE Windows so it can be at a fixed offset
        $winSizeParam = @{}
        $recoveryLetter = $null

        if ($RecoveryPartitionSizeMB -gt 0) {
            # Calculate Windows partition size
            if ($WindowsPartitionSizeGB -gt 0) {
                $winSizeParam = @{ Size = [int64]$WindowsPartitionSizeGB * 1GB }
            }
            else {
                # Leave room for recovery at the end; use remaining space minus recovery
                $winSizeParam = @{ Size = (Get-Disk -Number $diskNumber).LargestFreeExtent - ([int64]$RecoveryPartitionSizeMB * 1MB) }
            }

            # Windows OS partition
            Write-Info "Creating Windows partition ($([math]::Round($winSizeParam.Size / 1GB, 1)) GB)..."
            $winPart = New-Partition -DiskNumber $diskNumber @winSizeParam -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" # Basic Data
            $winLetter = Get-UnusedDriveLetter
            Add-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber $winPart.PartitionNumber -AccessPath $winLetter
            Format-Volume -DriveLetter $winLetter.TrimEnd(':') -FileSystem NTFS -NewFileSystemLabel "Windows" -Force | Out-Null
            Write-Success "Windows partition created at $winLetter"

            # Windows RE / Recovery partition — end of disk
            Write-Info "Creating Recovery partition ($RecoveryPartitionSizeMB MB)..."
            $recPart = New-Partition -DiskNumber $diskNumber -UseMaximumSize `
                                     -GptType "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}" # WinRE
            $recoveryLetter = Get-UnusedDriveLetter
            Add-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber $recPart.PartitionNumber -AccessPath $recoveryLetter
            Format-Volume -DriveLetter $recoveryLetter.TrimEnd(':') -FileSystem NTFS -NewFileSystemLabel "Recovery" -Force | Out-Null

            # Set Recovery partition attributes (Required + NoAutoMount + Hidden)
            $recPartObj = Get-Partition -DiskNumber $diskNumber -PartitionNumber $recPart.PartitionNumber
            $recPartObj | Set-Partition -GptType "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}" -NoDefaultDriveLetter $true
            Write-Success "Recovery partition created at $recoveryLetter"
        }
        else {
            # No recovery — Windows gets all remaining space
            if ($WindowsPartitionSizeGB -gt 0) {
                $winSizeParam = @{ Size = [int64]$WindowsPartitionSizeGB * 1GB }
            }
            else {
                $winSizeParam = @{ UseMaximumSize = $true }
            }

            Write-Info "Creating Windows partition..."
            $winPart = New-Partition -DiskNumber $diskNumber @winSizeParam -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
            $winLetter = Get-UnusedDriveLetter
            Add-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber $winPart.PartitionNumber -AccessPath $winLetter
            Format-Volume -DriveLetter $winLetter.TrimEnd(':') -FileSystem NTFS -NewFileSystemLabel "Windows" -Force | Out-Null
            Write-Success "Windows partition created at $winLetter"
        }
    }

    # ── MBR / BIOS layout ─────────────────────────────────────────────────────
    else {

        Write-Step "Creating MBR partitions (System Reserved + Windows$(if ($RecoveryPartitionSizeMB -gt 0) {' + Recovery'}))"

        # System Reserved — 500 MB, NTFS, active
        Write-Info "Creating System Reserved partition (500 MB)..."
        $sysPart = New-Partition -DiskNumber $diskNumber -Size 500MB -IsActive
        $sysLetter = Get-UnusedDriveLetter
        Add-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber $sysPart.PartitionNumber -AccessPath $sysLetter
        Format-Volume -DriveLetter $sysLetter.TrimEnd(':') -FileSystem NTFS -NewFileSystemLabel "System Reserved" -Force | Out-Null
        Write-Success "System Reserved partition created at $sysLetter"

        # Windows OS partition
        $winSizeParam = @{}
        if ($RecoveryPartitionSizeMB -gt 0) {
            if ($WindowsPartitionSizeGB -gt 0) {
                $winSizeParam = @{ Size = [int64]$WindowsPartitionSizeGB * 1GB }
            }
            else {
                $winSizeParam = @{ Size = (Get-Disk -Number $diskNumber).LargestFreeExtent - ([int64]$RecoveryPartitionSizeMB * 1MB) }
            }
        }
        else {
            if ($WindowsPartitionSizeGB -gt 0) {
                $winSizeParam = @{ Size = [int64]$WindowsPartitionSizeGB * 1GB }
            }
            else {
                $winSizeParam = @{ UseMaximumSize = $true }
            }
        }

        Write-Info "Creating Windows partition ($([math]::Round(($winSizeParam.ContainsKey('Size') ? $winSizeParam.Size : (Get-Disk -Number $diskNumber).LargestFreeExtent) / 1GB, 1)) GB)..."
        $winPart = New-Partition -DiskNumber $diskNumber @winSizeParam
        $winLetter = Get-UnusedDriveLetter
        Add-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber $winPart.PartitionNumber -AccessPath $winLetter
        Format-Volume -DriveLetter $winLetter.TrimEnd(':') -FileSystem NTFS -NewFileSystemLabel "Windows" -Force | Out-Null
        Write-Success "Windows partition created at $winLetter"

        # Recovery partition (optional)
        if ($RecoveryPartitionSizeMB -gt 0) {
            Write-Info "Creating Recovery partition ($RecoveryPartitionSizeMB MB)..."
            $recPart = New-Partition -DiskNumber $diskNumber -UseMaximumSize
            $recoveryLetter = Get-UnusedDriveLetter
            Add-PartitionAccessPath -DiskNumber $diskNumber -PartitionNumber $recPart.PartitionNumber -AccessPath $recoveryLetter
            Format-Volume -DriveLetter $recoveryLetter.TrimEnd(':') -FileSystem NTFS -NewFileSystemLabel "Recovery" -Force | Out-Null
            Write-Success "Recovery partition created at $recoveryLetter"
        }
    }

    # ─── Step 4: Apply WIM image ──────────────────────────────────────────────

    Write-Step "Applying WIM image (index $WIMIndex) to $winLetter"
    Write-Info "Source : $WIMPath"
    Write-Info "Target : $winLetter"
    Write-Info "Image  : $($wimInfo.ImageName)"

    Invoke-DismCommand @(
        "/Apply-Image",
        "/ImageFile:`"$WIMPath`"",
        "/Index:$WIMIndex",
        "/ApplyDir:`"$winLetter\`""
    )

    Write-Success "WIM image applied successfully."

    # ─── Step 5: Stamp the bootloader ─────────────────────────────────────────

    Write-Step "Configuring bootloader (BCDboot)"

    if ($PartitionStyle -eq "GPT") {
        # BCDboot writes BCD to the EFI partition
        Invoke-BcdbootCommand @(
            "$winLetter\Windows",
            "/s", $efiLetter,
            "/f", "UEFI",
            "/l", "en-US"
        )
        Write-Success "UEFI bootloader written to EFI partition ($efiLetter)."
    }
    else {
        # BCDboot writes BCD to System Reserved
        Invoke-BcdbootCommand @(
            "$winLetter\Windows",
            "/s", $sysLetter,
            "/f", "BIOS",
            "/l", "en-US"
        )
        Write-Success "BIOS bootloader written to System Reserved ($sysLetter)."
    }

    # ─── Step 6: Cleanup ──────────────────────────────────────────────────────

    Write-Step "Removing temporary drive letter assignments"

    # Remove all temporary drive letters assigned during this script
    $lettersToRemove = @()
    if ($PartitionStyle -eq "GPT") { $lettersToRemove += $efiLetter }
    else                            { $lettersToRemove += $sysLetter }
    $lettersToRemove += $winLetter
    if ($recoveryLetter) { $lettersToRemove += $recoveryLetter }

    foreach ($letter in $lettersToRemove) {
        try {
            $driveLetter = $letter.TrimEnd(':')
            $partition = Get-Partition | Where-Object { $_.DriveLetter -eq $driveLetter }
            if ($partition) {
                Remove-PartitionAccessPath -DiskNumber $diskNumber `
                                           -PartitionNumber $partition.PartitionNumber `
                                           -AccessPath $letter
                Write-Info "Removed drive letter $letter"
            }
        }
        catch {
            Write-Warning "Could not remove drive letter $letter`: $_"
        }
    }

}
catch {
    Write-Host "`n[ERROR] $_" -ForegroundColor Red
    Write-Host "  Cleaning up — dismounting VHDX..." -ForegroundColor Yellow
    try { Dismount-VHD -Path $VHDXPath -ErrorAction SilentlyContinue } catch {}
    throw
}
finally {

    Write-Step "Dismounting VHDX"
    Dismount-VHD -Path $VHDXPath
    Write-Success "VHDX dismounted."

}

# ─── Done ─────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  VHDX creation complete." -ForegroundColor Green
Write-Host "  Path   : $VHDXPath" -ForegroundColor Green
Write-Host "  Style  : $PartitionStyle  |  Type: $DiskType  |  Size: $DiskSizeGB GB" -ForegroundColor Green
Write-Host "  Image  : [$WIMIndex] $($wimInfo.ImageName)" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""