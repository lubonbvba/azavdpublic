#Update office

# Function to get the current Office version
function Get-OfficeVersion {
    try {
        $OfficeRegPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
        $OfficeVersion = (Get-ItemProperty -Path $OfficeRegPath).VersionToReport
        return $OfficeVersion
    } catch {
        Write-Host "Unable to retrieve Office version."
        return $null
    }
}

# Report Office version before the update
$BeforeUpdateVersion = Get-OfficeVersion
Write-Host "Office version before update: $BeforeUpdateVersion"

# Path to the OfficeC2RClient executable
$OfficeC2RClientPath = "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe"
$Arguments = "/update user updatetoversion=16.0.17928.20392 displaylevel=false forceappshutdown=true"

# Start the update process
Write-Host "Starting Office 365 update..."
$OfficeProcess = Start-Process -FilePath $OfficeC2RClientPath -ArgumentList $Arguments -PassThru

# Wait a moment for the new process to spawn
Start-Sleep -Seconds 15

# Monitor OfficeClickToRun processes until only one remains
do {
    $OfficeProcesses = Get-Process | Where-Object { $_.ProcessName -eq "OfficeClickToRun" }
    Start-Sleep -Seconds 5
} while ($OfficeProcesses.Count -ne 1)

Start-Sleep -Seconds 300

Write-Host "Update process finished."

# Report Office version after the update
$AfterUpdateVersion = Get-OfficeVersion
Write-Host "Office version after update: $AfterUpdateVersion"

# Compare versions
if ($BeforeUpdateVersion -ne $AfterUpdateVersion) {
    Write-Host "Office 365 has been successfully updated from version $BeforeUpdateVersion to $AfterUpdateVersion."
} else {
    Write-Host "Office 365 update did not result in a version change. Current version is still $BeforeUpdateVersion."
}
