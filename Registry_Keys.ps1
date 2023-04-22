[string[]]$gallerylocations = (
    "https://download.girardhome.com/hyper-v/gallery.json",
    "https://go.microsoft.com/fwlink/?linkid=851584"
)

$registrypath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization"
Set-ItemProperty -Path $registrypath -Name GalleryLocations -Value $gallerylocations