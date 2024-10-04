#Uninstall Remote Desktop WebRTC Redirector Service and install latest version

# Check if WebRTC is installed
$webRTCUninstallKey = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*Remote Desktop WebRTC Redirector Service*" }
if ($webRTCUninstallKey) {
    # Uninstall Remote Desktop WebRTC Redirector Service
    Write-Host "Remote Desktop WebRTC Redirector Service is installed. Uninstalling..."
    Start-Process msiexec.exe -ArgumentList "/x $($webRTCUninstallKey.PSChildName) /qn" -Wait
    Write-Host "Remote Desktop WebRTC Redirector Service has been uninstalled."
}
else {
    Write-Host "Remote Desktop WebRTC Redirector Service is not installed."
}

# Install the Remote Desktop WebRTC Redirector Service
# Create working dir
$workingDir = "C:\Temp\AVD\Teams"
New-Item -ItemType Directory -Path $workingDir -Force

$url = "https://aka.ms/msrdcwebrtcsvc/msi"
$webRTC = "MsRdcWebRTCSvc_x64.msi"
Invoke-WebRequest -Uri $url -OutFile "$workingDir\$webRTC" -UseBasicParsing
Start-Process -FilePath "$workingDir\$webRTC" -Args "/quiet /norestart /log C:\Temp\AVD\webrtc.log" -Wait
Write-Output "Finished the installation of Remote Desktop WebRTC Redirector Service"

# Check if installation was successful
$regLocation = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
foreach ($Key in (Get-ChildItem $regLocation) ) {
    if ($Key.GetValue('DisplayName') -like '*Remote Desktop WebRTC Redirector Service*') {
        $webRTCInstall = $true
    }
} 
if ($webRTCInstall) {
    Write-Output "WebRTC installed"
}
else {
    Write-Output "WebRTC installation failed"
}