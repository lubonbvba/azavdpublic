#Install New Teams with AVD optimizations

# Create working dir
$workingDir = "C:\Temp\AVD\Teams"
New-Item -ItemType Directory -Path $workingDir -Force

# Add Regkey for Teams optimization on AVD
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name IsWVDEnvironment -PropertyType DWORD -Value 1 -Force

# Install the Remote Desktop WebRTC Redirector Service
$url = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RW1jLHP"
$webRTC = "MsRdcWebRTCSvc_x64.msi"
Invoke-WebRequest -Uri $url -OutFile "$workingDir\$webRTC" -UseBasicParsing
Start-Process -FilePath "$workingDir\$webRTC" -Args "/quiet /norestart /log C:\Temp\AVD\webrtc.log" -Wait
Write-Output "Finished the installation of Remote Desktop WebRTC Redirector Service"

# Download New Teams files
$url = "https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409"
$teamsexe = "teamsbootstrapper.exe"
Invoke-WebRequest -Uri $url -OutFile "$workingDir\$teamsexe"

# Install New Teams
Write-Output "Install New Teams"
Start-Process "$workingDir\$teamsexe" -ArgumentList "-p" -Wait

# Check if installations are successfull
$regLocation = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
foreach ($Key in (Get-ChildItem $regLocation) ) {
    if ($Key.GetValue('DisplayName') -like '*Remote Desktop WebRTC Redirector Service*') {
      $webRTCInstall = $true
    }
  } 
if($webRTCInstall){
    Write-Output "WebRTC installed"
} else {
    Write-Output "WebRTC installation failed"
  }

if(Get-ProvisionedAppPackage -Online | Where-Object {$PSItem. DisplayName -eq "MSTeams"}){
    Write-Output "Teams installed"
} else {
    Write-Output "Teams installation failed"
}