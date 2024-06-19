function Test-PendingReboot {
  if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
  if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
  if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
  try { 
    $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
    $status = $util.DetermineIfRebootPending()
    if (($null -ne $status) -and $status.RebootPending) {
      return $true
    }
  }
  catch {}
 
  return $false
}

function Test-RebootRequired {
  $result = @{
    CBSRebootPending            = $false
    WindowsUpdateRebootRequired = $false
    FileRenamePending           = $false
    SCCMRebootPending           = $false
  }

  #Check CBS Registry
  $key = Get-ChildItem "HKLM:Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction Ignore
  if ($null -ne $key) {
    Write-Host "CBS Registry:"
    Write-Host $key
    $result.CBSRebootPending = $true
  }
   
  #Check Windows Update
  $key = Get-Item "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction Ignore
  if ($null -ne $key) {
    Write-Host "Windows Update:"
    Write-Host $key
    $result.WindowsUpdateRebootRequired = $true
  }

  #Check PendingFileRenameOperations
  $prop = Get-ItemProperty "HKLM:SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction Ignore
  if ($null -ne $prop) {
    # PendingFileRenameOperations is not *must* to reboot?
    $result.FileRenamePending = $true
  }
    
  #Check SCCM Client <http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542/view/Discussions#content>
  try { 
    $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
    $status = $util.DetermineIfRebootPending()
    if (($null -ne $status) -and $status.RebootPending) {
      $result.SCCMRebootPending = $true
    }
  }
  catch {}

  #Return Reboot required
  # return $result.ContainsValue($true)
  return $result
}

Test-RebootRequired
# Test-PendingReboot