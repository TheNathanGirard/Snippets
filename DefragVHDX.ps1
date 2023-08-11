# Get the VHDX file(s)
$VirtualDisks = Get-ChildItem -Path "C:\Virtual_Machines\Virtual hard disks" -Filter *.vhdx -Recurse

$Time = Measure-Command {
    [System.Collections.ArrayList]$VHDXInfo = @()
    foreach ($VHDX in $VirtualDisks) {
       
        $DiskSizeBeforeInGB = [math]::Round($(Get-Item -Path $VHDX.FullName).length / 1GB)

        $Mount = Mount-VHD -Path $VHDX.FullName -Passthru
        $Volumes = $Mount | Get-Disk | Get-Partition | Get-Volume | Select-Object -Property DriveLetter, FileSystem, Drivetype | Where-Object { $_.DriveLetter -notin '', $null } 

        # Defrag each volume
        foreach ($Volume in $Volumes) {

            $DriveLetter = $Volume.DriveLetter + ":"
            # Code for VHDX stored on SSD drives (not using /d)
            defrag $DriveLetter /x
            defrag $DriveLetter /k /l
            defrag $DriveLetter /x # repeated
            defrag $DriveLetter /k # repeated, but without trim (/l)
        }
        
        Dismount-VHD -Path $VHDX.FullName
        
        # Mount the VHDX file read-only, not mapping any drive letters
        Mount-VHD -Path $VHDX.FullName -NoDriveLetter -ReadOnly
        Optimize-VHD -Path $VHDX.FullName -Mode Full
        Dismount-VHD -Path $VHDX.FullName

        $DiskSizeAfterInGB = [math]::Round($(Get-Item -Path $VHDX.FullName).length / 1GB)

        $obj = [PSCustomObject]@{

            # Add values to arraylist
            DiskSizeBeforeInGB = $DiskSizeBeforeInGB
            DiskSizeAfterInGB  = $DiskSizeAfterInGB
        }

        # Add all the values
        $VHDXInfo.Add($obj) | Out-Null
    }

    $TotalDiskSizeBeforeInGB = ($VHDXInfo.DiskSizeBeforeInGB | Measure-Object -Sum).Sum
    $TotalDiskSizeAfterInGB = ($VHDXInfo.DiskSizeAfterInGB | Measure-Object -Sum).Sum
    $SavingsInGB = $TotalDiskSizeBeforeInGB - $TotalDiskSizeAfterInGB
    Write-Host "Total disk size before optimization: $TotalDiskSizeBeforeInGB GB"
    Write-Host "Total disk size after optimization: $TotalDiskSizeAfterInGB GB"
    Write-Host "Total savings after optimization is: $SavingsInGB GB"

}

Write-Host "Optimization runtime was $($Time.Minutes) minutes and $($Time.Seconds) Seconds"
