$registrypath = "HKCU:\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
Set-ItemProperty -Path $registrypath -Name InprocServer32 -Value ""
