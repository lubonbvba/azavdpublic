#Install New Teams with AVD optimizations

# Create working dir
$workingDir = "C:\Temp\AVD\Teams"
New-Item -ItemType Directory -Path $workingDir -Force

# Add Regkey for Teams optimization on AVD
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name IsWVDEnvironment -PropertyType DWORD -Value 1 -Force

# Disable auto update
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name disableAutoUpdate -PropertyType DWORD -Value 1 -Force

# Install the Remote Desktop WebRTC Redirector Service
$url = "https://aka.ms/msrdcwebrtcsvc/msi"
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

# Install Teams meeting add-in for all users
If (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator') ){
  Write-Error "Need to run as administrator. Exiting.."
  exit 1
}

# Get Version of currently installed new Teams Package
if (-not ($NewTeamsPackageVersion = (Get-AppxPackage -Name MSTeams).Version)) {
  Write-Host "New Teams Package not found. Please install new Teams from https://aka.ms/GetTeams ."
  exit 1
}
Write-Host "Found new Teams Version: $NewTeamsPackageVersion"

# Get Teams Meeting Addin Version
$TMAPath = "{0}\WINDOWSAPPS\MSTEAMS_{1}_X64__8WEKYB3D8BBWE\MICROSOFTTEAMSMEETINGADDININSTALLER.MSI" -f $env:programfiles,$NewTeamsPackageVersion
if (-not ($TMAVersion = (Get-AppLockerFileInformation -Path $TMAPath | Select-Object -ExpandProperty Publisher).BinaryVersion))
{
  Write-Host "Teams Meeting Addin not found in $TMAPath."
  exit 1
}
Write-Host "Found Teams Meeting Addin Version: $TMAVersion"

# Install parameters
$TargetDir = "{0}\Microsoft\TeamsMeetingAddin\{1}\" -f ${env:ProgramFiles(x86)},$TMAVersion
$params = '/i "{0}" TARGETDIR="{1}" /qn ALLUSERS=1' -f $TMAPath, $TargetDir

# Start the install process
write-host "executing msiexec.exe $params"
Start-Process msiexec.exe -ArgumentList $params -Wait

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

  foreach ($Key in (Get-ChildItem $regLocation) ) {
    if ($Key.GetValue('DisplayName') -like '*Microsoft Teams Meeting Add-in for Microsoft Office*') {
      $teamsMeetingAddIn = $true
    }
  } 
if( $teamsMeetingAddIn){
    Write-Output "Teams Meeting Add-in installed"
} else {
    Write-Output "Teams Meeting Add-in installation failed"
  }

if(Get-ProvisionedAppPackage -Online | Where-Object {$PSItem. DisplayName -eq "MSTeams"}){
    Write-Output "Teams installed"
} else {
    Write-Output "Teams installation failed"
}