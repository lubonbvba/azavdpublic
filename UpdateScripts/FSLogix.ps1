#description: Downloads and installs FSLogix on the session hosts
#Written by Johan Vanneuville
#No warranties given for this script
#execution mode: IndividualWithRestart
#tags: Nerdio, Apps install, FSLogix
<#
Notes:
This script installs or updates FSLogix on AVD Session host and reboots the host if needed.
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('latest', 'v25', 'v22')]
    [string]$FslogixVersion = "latest"
)

# Determine FSLogix download URL based on version parameter
if ($FslogixVersion -eq "v25") {
    $FslogixUrl = "https://download.microsoft.com/download/8fc0f8ba-e928-4aa7-8b85-f6655b6a15ab/FSLogix_25.09.zip"
}
# FSLogix 2210 hotfix 4
elseif ($FslogixVersion -eq "v22") {
    $FslogixUrl = "https://download.microsoft.com/download/e/c/4/ec4b55b3-d2f3-4610-aebd-56478eb0d582/FSLogix_Apps_2.9.8884.27471.zip"
}
else {
    $FslogixUrl = "https://aka.ms/fslogix_download"
}

# Start powershell logging
$SaveVerbosePreference = $VerbosePreference
$VerbosePreference = 'continue'
$VMTime = Get-Date
$LogTime = $VMTime.ToUniversalTime()

# Set new working directory
$FslogixWorkingDir = "C:\Temp\AVD\FSLogix"
if (-not (Test-Path $FslogixWorkingDir)) {
    mkdir $FslogixWorkingDir | Out-Null
}

Start-Transcript -Path "C:\Windows\temp\fslogix\ScriptedActions\fslogix\ps_log.txt" -Append
Write-Host "################# New Script Run #################"
Write-host "Current time (UTC-0): $LogTime"

Invoke-WebRequest -Uri $FslogixUrl -OutFile "$FslogixWorkingDir\FSLogixAppsSetup_$FslogixVersion.zip" -UseBasicParsing

Expand-Archive `
    -LiteralPath "$FslogixWorkingDir\FSLogixAppsSetup_$FslogixVersion.zip" `
    -DestinationPath $FslogixWorkingDir `
    -Force `
    -Verbose
Set-Location $FslogixWorkingDir

# Install FSLogix.
Write-Host "INFO: Installing FSLogix. . ."
Start-Process "$FslogixWorkingDir\x64\Release\FSLogixAppsSetup.exe" `
    -ArgumentList "/install /quiet" `
    -Wait `
    -Passthru

Write-Host "INFO: FSLogix install finished."

# End Logging
Stop-Transcript
$VerbosePreference = $SaveVerbosePreference