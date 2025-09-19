#description: Downloads and installs FSLogix on the session hosts
#Written by Johan Vanneuville
#No warranties given for this script
#execution mode: IndividualWithRestart
#tags: Nerdio, Apps install, FSLogix
<#
Notes:
This script installs or updates FSLogix on AVD Session host and reboots the host if needed.
#>

$FslogixUrl = "https://aka.ms/fslogix_download"

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

Invoke-WebRequest -Uri $FslogixUrl -OutFile "$FslogixWorkingDir\FSLogixAppsSetup.zip" -UseBasicParsing

Expand-Archive `
    -LiteralPath "$FslogixWorkingDir\FSLogixAppsSetup.zip" `
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