#Install Powershell 7

# Create working dir
$workingDir = "C:\Temp"
New-Item -ItemType Directory -Path $workingDir -Force

# Download latest version
$URL = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.3/PowerShell-7.4.3-win-x64.msi"
$setup = "PowerShell-7.4.3-win-x64.msi"
Invoke-WebRequest -Uri $URL -OutFile "$workingDir\$setup"

# Install
Start-Process "$workingDir\$setup" -ArgumentList "/quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1" -Wait

# Check if powershell was installed
if (Test-Path "HKLM:\SOFTWARE\Microsoft\PowerShellCore") {
    Write-Output "Powershell 7 was successfully installed for all users"
} else {
    Write-Output "Installation failed"
    Write-Output "Registry key 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PowerShellCore' does not exist."
    Exit 1
}
