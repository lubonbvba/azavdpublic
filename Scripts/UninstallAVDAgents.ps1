# Remove AVD agents

# Define programs to uninstall
$uninstalledPrograms = @(
    "Remote Desktop Agent Boot Loader",
    "Remote Desktop Services Infrastructure Agent",
    "Remote Desktop Services Infrastructure Geneva Agent*",
    "Remote Desktop Services SxS Network Stack",
    "Microsoft Intune Management Extension",
    "System Settings Proxy"
)

# Uninstall programs
foreach ($program in $uninstalledPrograms) {
    Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like $program } | ForEach-Object {
        Write-Host "Uninstalling $($_.Name)"
        $_.Uninstall() | Out-Null
    }
}

# Pause to allow uninstalls to complete
Start-Sleep -Seconds 30

# Check if uninstall was successful
Write-Output "Checking registry for remaining installations..."
foreach ($programName in $uninstalledPrograms) {
    $registryKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
                   Where-Object { $_.DisplayName -like $programName }
    
    if ($registryKey) {
        Write-Warning "$programName is still installed."
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

# Cleanup Azure Monitor Agent
$regPath = "HKLM:\SOFTWARE\Microsoft\AzureMonitorAgent\Secrets"
$regValue = "PersistenceKeyCreated"
if (Test-Path $regPath) {
    if (Get-ItemProperty -Path $regPath -Name $regValue -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $regPath -Name $regValue -Force
        Write-Output "Registry value '$regValue' has been successfully deleted from $regPath."
    } else {
        Write-Output "Registry value '$regValue' does not exist in $regPath."
    }
} else {
    Write-Output "Registry key $regPath does not exist."
}

Write-Output "Delete AMA datastore"
Get-ChildItem -Path "C:\WindowsAzure\Resources" -Directory -Filter "AMADataStore*" | Remove-Item -Recurse -Force

# Remove .msi files from C:\Program Files\Microsoft RDInfra
$msiFiles = Get-ChildItem -Path "C:\Program Files\Microsoft RDInfra" -Filter *.msi -Recurse -ErrorAction SilentlyContinue

if ($msiFiles) {
    foreach ($msi in $msiFiles) {
        Write-Host "Deleting $($msi.FullName)"
        Remove-Item -Path $msi.FullName -Force
    }
    Write-Output "All .msi files in C:\Program Files\Microsoft RDInfra have been deleted."
} else {
    Write-Output "No .msi files found in C:\Program Files\Microsoft RDInfra."
}