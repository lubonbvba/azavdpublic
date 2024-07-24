# Install eID

# Create working dir
$workingDir = "C:\Temp\AVD"
New-Item -ItemType Directory -Path $workingDir -Force

# Download latest version
$URL = "https://eid.belgium.be/sites/default/files/software/Belgium%20eID-QuickInstaller%205.1.8.6030.exe"
$setup = "Belgium eID-QuickInstaller 5.1.8.6030.exe"
Invoke-WebRequest -Uri $URL -OutFile "$workingDir\$setup"

$URLViewer = "https://eid.belgium.be/sites/default/files/software/Belgium%20eID%20Viewer%20Installer%205.1.12.6095.exe"
$setupViewer = "Belgium eID Viewer Installer 5.1.12.6095.exe"
Invoke-WebRequest -Uri $URLViewer -OutFile "$workingDir\$setupViewer"

# Install
Write-Output "Installing eID Quick Installer"
Start-Process "$workingDir\$setup" -ArgumentList "/S" -Wait

Write-Output "Installing eID Viewer Installer"
Start-Process "$workingDir\$setupViewer" -ArgumentList "/S" -Wait

# Check if software is installed
$RegLocations = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$Installed = $False
foreach ($Key in (Get-ChildItem $RegLocations) ) {
  if ($Key.GetValue('DisplayName') -like 'Belgium e-ID middleware*') {
    $Installed = $True
  }
}
if ($Installed) {
    Write-Output "Belgium eID middleware installed"
  }
  else {
    Write-Output "Belgium eID middleware install failed"
  }


$Installed = $False
foreach ($Key in (Get-ChildItem $RegLocations) ) {
  if ($Key.GetValue('DisplayName') -like 'Belgium e-ID viewer*') {
    $Installed = $True
  }
}
if ($Installed) {
    Write-Output "Belgium eID viewer installed"
  }
  else {
    Write-Output "Belgium eID viewer install failed"
  }

# Delete installers
Remove-Item "$workingDir\$setup"
Remove-Item "$workingDir\$setupViewer"