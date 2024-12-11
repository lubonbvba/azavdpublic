#Uninstall all Office365 versions

#Create working dir
$workingDir = "C:\Temp\AVD\Office"
New-Item -ItemType Directory -Path $workingDir -Force

function Write-Log {
  param(
          [parameter(Mandatory)]
          [string]$Message,
  
          [parameter(Mandatory)]
          [string]$Type
  )
  #$Path = 'C:\Temp\AVD\OfficeInstall.log'
  if (!(Test-Path -Path $workingDir)) {
          New-Item -Path $workingDir -Name 'OfficeInstall.log' | Out-Null
  }
  $Timestamp = Get-Date -Format 'dd/MM/yyyy HH:mm:ss.ff'
  $Entry = '[' + $Timestamp + '] [' + $Type + '] ' + $Message
  $Entry | Out-File -FilePath "$workingDir\OfficeUninstall.log" -Append
  }

function Get-ODTURL {

  [String]$MSWebPage = Invoke-RestMethod -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=49117'
  
  $regex = 'https:\/\/download\.microsoft\.com\/download\/.*?\/.*?\.exe'
  $matchesUrl = [regex]::Matches($MSWebPage, $regex)

  if ($matchesUrl.Count -gt 0) {
    $matchesUrl[0].Value
  }
  else {
    Write-Output "No download URL found."
  }
}

# Download All files
Write-Log -Message "Downloading Office deployment tool" -Type 'INFO'
$ODTUrl = Get-ODTURL
Invoke-WebRequest -Uri $ODTUrl -OutFile "$workingDir\OfficeDeploymentTool.exe"

# Extract ODT
#Write-Log -Message "Extracting ODT" -Type 'INFO'
Start-Process "$workingDir\OfficeDeploymentTool.exe" -ArgumentList "/quiet /extract:`"$workingDir`"" -Wait
#Write-Log -Message "Removing ODT" -Type 'INFO'
Remove-Item -Path "$workingDir\OfficeDeploymentTool.exe" -Force

# Generate office config xml file 
$xmlContent = @"
<Configuration>
    <!--Uninstall complete Office 365-->
    <Display Level="None" AcceptEULA="TRUE" />
    <Logging Level="Standard" Path="%temp%" />
    <Remove All="TRUE" />
</Configuration>
"@

# Write the content to the file
$configXMLFile = "UninstallOffice365.xml"
$xmlContent | Out-File -FilePath "$workingDir\$configXMLFile" -Encoding UTF8 -Force

# Confirm the file creation
Write-Output "File 'UninstallOffice365.xml' created at $workingDir"

# Run the O365 install
try {
    Write-Log -Message 'Downloading and installing Microsoft 365' -Type "INFO"
    $Silent = Start-Process "$workingDir\Setup.exe" -ArgumentList "/configure $workingDir\$configXMLFile" -Wait -PassThru
  }
  catch {
    Write-Log -Message "Error running the Office install" -Type "ERROR"
    Write-Log -Message $_ -Type "ERROR"
  }

# Check if Office 365  was uninstalled correctly.
$RegLocations = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$OfficeInstalled = $true
foreach ($Key in (Get-ChildItem $RegLocations) ) {
  if ($Key.GetValue('DisplayName') -like '*Microsoft 365*') {
    $OfficeInstalled = $True
  }
}

if ($OfficeInstalled) {
  Write-Output "Office Removed Successfully"
}
else {
  Write-Log -Message "Office Removal Failed" -Type "ERROR"
}