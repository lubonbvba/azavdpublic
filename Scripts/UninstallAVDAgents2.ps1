#Remove AVD agents

# Define programs to uninstall
$uninstalledPrograms = @(
    "*remote Desktop Services*",
    "*remote Desktop agent*",
    "Microsoft Intune Management Extension"
)

# Uninstall programs
foreach ($program in $uninstalledPrograms) {
    (Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $program }).Uninstall() | Out-Null
}

# Pause to allow uninstalls to complete
Start-Sleep -Seconds 30

# Check if uninstall was successful
Write-Output "Check registry for installations"
foreach ($programName in $uninstalledPrograms) {
    $registryKey = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Get-ItemProperty | Where-Object { $_.DisplayName -like $programName }
    if ($registryKey) {
        Write-Error "$programName is still installed."
    } else {
        Write-Output "$programName has been successfully uninstalled."
    }
}

# Delete specific registry keys
$regKeysToDelete = @(
    #"HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent"
    "HKLM:\SOFTWARE\Microsoft\RDInfraAgent"
)

foreach ($regKey in $regKeysToDelete) {
    if (Test-Path $regKey) {
        Remove-Item -Path $regKey -Recurse -Force
        Write-Output "$regKey has been successfully deleted."
    } else {
        Write-Output "$regKey does not exist."
    }
}