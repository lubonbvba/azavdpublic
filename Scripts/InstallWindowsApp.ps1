#Install Windows App for all users

# Create working dir
$workingDir = "C:\Temp\AVD"
New-Item -ItemType Directory -Path $workingDir -Force

# Download latest version
$URL = "https://go.microsoft.com/fwlink/?linkid=2318620"
$setup = "WindowsApp_x64.msix"
Invoke-WebRequest -Uri $URL -OutFile "$workingDir\$setup"

# Install
Add-AppxProvisionedPackage -Online -PackagePath "$workingDir\$setup" -SkipLicense

# Check if package was installed
if (Get-AppxPackage -AllUsers -Name "*MicrosoftCorporationII.Windows365*") {
    Write-Host "Windows App installed successfully."
} else {
    Write-Host "Windows App installation failed."
    exit 1
}