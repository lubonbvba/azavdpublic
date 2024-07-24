#Install Office 365

param(
    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Specify Office channel, Monthly Enterprise (MEC) or Semi-Annual Enterprise Channel (SEC) ")]
    [ValidateSet("MEC", "SEC")]
    [string]$channel = "SEC"
)

# Create working dir
$workingDir = "C:\Temp\AVD\Office"
New-Item -ItemType Directory -Path $workingDir -Force

# Define functions
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
    $Entry | Out-File -FilePath "$workingDir\OfficeInstall.log" -Append
    }
    
function Get-ODTURL {

    [String]$MSWebPage = Invoke-RestMethod 'https://www.microsoft.com/en-us/download/confirmation.aspx?id=49117'
  
    $MSWebPage | ForEach-Object {
      if ($_ -match 'url=(https://.*officedeploymenttool.*\.exe)') {
        $matches[1]
      }
    }
}

# Download All files
Write-Log -Message "Downloading Office deployment tool" -Type 'INFO'
$ODTUrl = Get-ODTURL
Invoke-WebRequest -Uri $ODTUrl -OutFile "$workingDir\OfficeDeploymentTool.exe"

if($channel -eq "MEC"){
    Write-Log -Message "Downloading Office Monthly Enterprise configuration file" -Type 'INFO'
    $MECUrl = "https://raw.githubusercontent.com/lubonbvba/azavdpublic/main/Scripts/Office/Configuration-Monthly-Enterprise.xml"
    $configXMLFile = "Configuratie-Monthly-Enterprise.xml" 
    Invoke-WebRequest -Uri $MECUrl -OutFile "$workingDir\$configXMLFile"
}

if($channel -eq "SEC"){
    Write-Log -Message "Downloading Office Semi-Anual Enterprise configuration file" -Type 'INFO'
    $SECUrl = "https://raw.githubusercontent.com/lubonbvba/azavdpublic/main/Scripts/Office/Configuration-Semi-Anual-Enterprise.xml"
    $configXMLFile = "Configuratie-Semi-Anual-Enterprise.xml"
    Invoke-WebRequest -Uri $SECUrl -OutFile "$workingDir\$configXMLFile"
}

# Extract ODT
Write-Log -Message "Extracting ODT" -Type 'INFO'
Start-Process "$workingDir\OfficeDeploymentTool.exe" -ArgumentList "/quiet /extract:`"$workingDir`"" -Wait
Write-Log -Message "Removing ODT" -Type 'INFO'
Remove-Item -Path "$workingDir\OfficeDeploymentTool.exe" -Force

# Run the O365 install
try {
    Write-Log -Message 'Downloading and installing Microsoft 365' -Type "INFO"
    $Silent = Start-Process "$workingDir\Setup.exe" -ArgumentList "/configure $workingDir\$configXMLFile" -Wait -PassThru
  }
  catch {
    Write-Log -Message "Error running the Office install" -Type "ERROR"
    Write-Log -Message $_ -Type "ERROR"
  }

# Check if Office 365  was installed correctly.
$RegLocations = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

$OfficeInstalled = $False
foreach ($Key in (Get-ChildItem $RegLocations) ) {
  if ($Key.GetValue('DisplayName') -like '*Microsoft 365*') {
    Write-Log -Message $Key.GetValue('DisplayName') -Type "INFO"
    Write-Log -Message $Key.GetValue('DisplayVersion') -Type "INFO"
    $OfficeInstalled = $True
  }
}

if ($OfficeInstalled) {
  Write-Log -Message "Office Installed Successfully" -Type "INFO"
}
else {
  Write-Log -Message "Office Instalation Failed" -Type "ERROR"
}
