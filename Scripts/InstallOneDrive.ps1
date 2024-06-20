#Install OneDrive per-machine

# Create working dir
$workingDir = "C:\Temp\AVD"
New-Item -ItemType Directory -Path $workingDir -Force

# Download latest version
$URL = "https://go.microsoft.com/fwlink/?linkid=844652"
$setup = "OneDriveSetup.exe"
Invoke-WebRequest -Uri $URL -OutFile "$workingDir\$setup"

# Install
Start-Process "$workingDir\$setup" -ArgumentList "/silent /allusers" -Wait

# Check if Onedrive was installed
if (Test-Path "HKLM:\SOFTWARE\Microsoft\OneDrive") {
    Write-Output "Onedrive was successfully installed for all users"
} else {
    Write-Output "Installation failed"
    Write-Output "Registry key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\OneDrive' does not exist."
    Exit 1
}
