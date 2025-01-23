#Update office by getting the latest build of the installed channel to prevent channel changes during update

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

# Function to get the current installed Office update channel
function Get-OfficeUpdateChannel {
    $Channel = (Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" -Name "CDNBaseUrl") -split "/" | Select-Object -Last 1

    if (!$Channel) {
        $ChannelId = "Non-C2R version or No Channel selected."
    }
    else {
        switch($Channel) {
            "492350f6-3a01-4f97-b9c0-c7c6ddf67d60"  { $ChannelId = "Current" }
            "64256afe-f5d9-4f86-8936-8840a6a4f5be"  { $ChannelId = "CurrentPreview" }
            "7ffbc6bf-bc32-4f92-8982-f9dd17fd3114"  { $ChannelId = "SemiAnnual" }
            "b8f9b850-328d-4355-9145-c59439a0c4cf"  { $ChannelId = "SemiAnnualPreview" }
            "55336b82-a18d-4dd6-b5f6-9e5095c314a6"  { $ChannelId = "MonthlyEnterprise" }
            "5440fd1f-7ecb-4221-8110-145efaa6372f"  { $ChannelId = "BetaChannel" }
        }
    }

    $ChannelId
}

# Get latest Office version information
$CloudVersionInfo = Invoke-RestMethod 'https://clients.config.office.net/releases/v1.0/OfficeReleases'

# Check if update is needed
$currentVersion = Get-OfficeVersion
$officeChannel = Get-OfficeUpdateChannel
$LatestBuild = $CloudVersionInfo | Where-Object { $_.channelId -eq $officeChannel } | Select-Object -ExpandProperty latestVersion
if ($currentVersion -eq $LatestBuild) {
    Write-Output "Currently using the latest version of Office in the '$officeChannel' Channel: $currentVersion"
}
else {
    # Report Office version before the update
    $BeforeUpdateVersion = Get-OfficeVersion
    Write-Host "Office version before update: $BeforeUpdateVersion"

    # Path to the OfficeC2RClient executable
    $OfficeC2RClientPath = "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe"
    $Arguments = "/update user updatetoversion=$latestBuild displaylevel=false forceappshutdown=true"

    # Start the update process
    Write-Host "Starting Office 365 update to build $latestBuild from channel '$officeChannel'..."
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
    }
    else {
        Write-Host "Office 365 update did not result in a version change. Current version is still $BeforeUpdateVersion."
    }

}

