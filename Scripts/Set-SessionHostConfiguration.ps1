Param(
[parameter(Mandatory=$false)]
[string]
$IdentityDomainName, 

[parameter(Mandatory)]
[string]
$AmdVmSize, 

[parameter(Mandatory)]
[string]
$IdentityServiceProvider,

[parameter(Mandatory)]
[string]
$Fslogix,

[parameter(Mandatory=$false)]
[string]
$FslogixFileShare,

[parameter(Mandatory=$false)]
[string]
$fslogixStorageFqdn,

[parameter(Mandatory)]
[string]
$HostPoolRegistrationToken,    

[parameter(Mandatory)]
[string]
$NvidiaVmSize

# [parameter(Mandatory)]
# [string]
# $ScreenCaptureProtection
)

##############################################################
#  Functions
##############################################################
function Write-Log {
param(
        [parameter(Mandatory)]
        [string]$Message,

        [parameter(Mandatory)]
        [string]$Type
)
$Path = 'C:\Windows\Temp\AVDSessionHostConfig.log'
if (!(Test-Path -Path $Path)) {
        New-Item -Path 'C:\' -Name 'AVDSessionHostConfig.log' -Force | Out-Null
}
$Timestamp = Get-Date -Format 'MM/dd/yyyy HH:mm:ss.ff'
$Entry = '[' + $Timestamp + '] [' + $Type + '] ' + $Message
$Entry | Out-File -FilePath $Path -Append
}

function Get-WebFile {
param(
        [parameter(Mandatory)]
        [string]$FileName,

        [parameter(Mandatory)]
        [string]$URL
)
$Counter = 0
do {
        Invoke-WebRequest -Uri $URL -OutFile $FileName -ErrorAction 'SilentlyContinue'
        if ($Counter -gt 0) {
                Start-Sleep -Seconds 30
        }
        $Counter++
}
until((Test-Path $FileName) -or $Counter -eq 9)
}

$ErrorActionPreference = 'Stop'

try {

        ##############################################################
        #  Run the Virtual Desktop Optimization Tool (VDOT)
        ##############################################################
        # https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool

        # Don't run vdot on server os
        if((Get-ComputerInfo).WindowsInstallationType -eq "Client"){

                # Download VDOT
                $URL = 'https://github.com/lubon-public/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip'
                $ZIP = 'VDOT.zip'
                Invoke-WebRequest -Uri $URL -OutFile $ZIP

                # Extract VDOT from ZIP archive
                Expand-Archive -LiteralPath $ZIP -Force

                # Fix to disable AppX Packages
                # As of 2/8/22, all AppX Packages are enabled by default
                # Define the list of AppxPackages to disable
                $appxPackagesToDisable = @(
                "Microsoft.549981C3F5F10"
                "Microsoft.BingNews",
                "Microsoft.BingWeather",
                "Microsoft.GamingApp",
                "Microsoft.Getstarted",
                "Microsoft.MicrosoftSolitaireCollection",
                #"Microsoft.OutlookForWindows",
                "Microsoft.People",
                "Microsoft.PowerAutomateDesktop",
                "Microsoft.SkypeApp",
                "Microsoft.WinDbg.Fast",
                "Microsoft.Windows.DevHome",
                "microsoft.windowscommunicationsapps",
                "Microsoft.WindowsFeedbackHub",
                "Microsoft.WindowsTerminal",
                "Microsoft.Xbox.TCUI",
                "Microsoft.XboxGameOverlay",
                "Microsoft.XboxGamingOverlay",
                "Microsoft.XboxIdentityProvider",
                "Microsoft.XboxSpeechToTextOverlay",
                "Microsoft.YourPhone",
                "Microsoft.ZuneMusic",
                "Microsoft.ZuneVideo",
                "MicrosoftWindows.Client.WebExperience",
                "Microsoft.XboxApp",
                "Microsoft.MixedReality.Portal",
                "Microsoft.Wallet" 
                )

                $Files = (Get-ChildItem -Path .\VDOT\Virtual-Desktop-Optimization-Tool-main -File -Recurse -Filter "AppxPackages.json").FullName

                foreach ($File in $Files) {
                        $jsonContent = Get-Content -Path $File | ConvertFrom-Json
                        foreach ($package in $jsonContent) {
                                # Check if the current AppxPackage is in the list to disable
                                if ($appxPackagesToDisable -contains $package.AppxPackage) {
                                # Update the VDIState property to 'Disabled'
                                $package.VDIState = "Disabled"
                                }
                        }

                        $jsonContent | ConvertTo-Json | Set-Content -Path $File
                }
                
                # Enable Geolocation service
                $services = (Get-ChildItem -Path .\VDOT\Virtual-Desktop-Optimization-Tool-main -File -Recurse -Filter "Services.json").FullName
                $jsonContent = Get-Content -Path $services | ConvertFrom-Json
                foreach ($service in $jsonContent) {
                        if ($service.Name -eq "lfsvc") {
                                $service.VDIState = "Unchanged"
                        }
                }
                $jsonContent | ConvertTo-Json | Set-Content -Path $services

                # Run VDOT
                If((Get-ComputerInfo).CsName -like "C0032*") {
                        Write-Log -Message "Run VDOT without RemoveLegacyIE" -Type 'INFO' 
                        & .\VDOT\Virtual-Desktop-Optimization-Tool-main\Windows_VDOT.ps1 -Optimizations AppxPackages,ScheduledTasks,DefaultUserSettings,LocalPolicy,Autologgers,Services,NetworkOptimizations -AdvancedOptimizations 'Edge' -AcceptEULA
                } else {
                        Write-Log -Message "Run VDOT" -Type 'INFO' 
                        & .\VDOT\Virtual-Desktop-Optimization-Tool-main\Windows_VDOT.ps1 -Optimizations AppxPackages,ScheduledTasks,DefaultUserSettings,LocalPolicy,Autologgers,Services,NetworkOptimizations -AdvancedOptimizations 'Edge', 'RemoveLegacyIE' -AcceptEULA
                }           
                
                Write-Log -Message 'Optimized the operating system using VDOT' -Type 'INFO'
        } else {
                Write-Log -Message 'Server Os detected skip VDOT' -Type 'INFO'
        }  

        ##############################################################
        #  Add Recommended AVD Settings
        ##############################################################
        $Settings = @(

                # Disable Automatic Updates: https://docs.microsoft.com/en-us/azure/virtual-desktop/set-up-customize-master-image#disable-automatic-updates
                [PSCustomObject]@{
                        Name         = 'NoAutoUpdate'
                        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
                        PropertyType = 'DWord'
                        Value        = 1
                },

                # Enable Time Zone Redirection: https://docs.microsoft.com/en-us/azure/virtual-desktop/set-up-customize-master-image#set-up-time-zone-redirection
                [PSCustomObject]@{
                        Name         = 'fEnableTimeZoneRedirection'
                        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
                        PropertyType = 'DWord'
                        Value        = 1
                },

                # Allow enable location
                [PSCustomObject]@{
                        Name         = 'Value'
                        Path         = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
                        PropertyType = 'String'
                        Value        = 'Allow'
                }
        )

        ##############################################################
        #  Add GPU Settings
        ##############################################################
        # This setting applies to the VM Size's recommended for AVD with a GPU
        if ($AmdVmSize -eq 'true' -or $NvidiaVmSize -eq 'true') {
                $Settings += @(

                        # Configure GPU-accelerated app rendering: https://docs.microsoft.com/en-us/azure/virtual-desktop/configure-vm-gpu#configure-gpu-accelerated-app-rendering
                        [PSCustomObject]@{
                                Name         = 'bEnumerateHWBeforeSW'
                                Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
                                PropertyType = 'DWord'
                                Value        = 1
                        },

                        # Configure fullscreen video encoding: https://docs.microsoft.com/en-us/azure/virtual-desktop/configure-vm-gpu#configure-fullscreen-video-encoding
                        [PSCustomObject]@{
                                Name         = 'AVC444ModePreferred'
                                Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
                                PropertyType = 'DWord'
                                Value        = 1
                        }
                )
        }
        # This setting applies only to VM Size's recommended for AVD with a Nvidia GPU
        if ($NvidiaVmSize -eq 'true') {
                $Settings += @(

                        # Configure GPU-accelerated frame encoding: https://docs.microsoft.com/en-us/azure/virtual-desktop/configure-vm-gpu#configure-gpu-accelerated-frame-encoding
                        [PSCustomObject]@{
                                Name         = 'AVChardwareEncodePreferred'
                                Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
                                PropertyType = 'DWord'
                                Value        = 1
                        }
                )
        }

        # ##############################################################
        # #  Add Screen Capture Protection Setting
        # ##############################################################
        # if ($ScreenCaptureProtection -eq 'true') {
        #         $Settings += @(

        #                 # Enable Screen Capture Protection: https://docs.microsoft.com/en-us/azure/virtual-desktop/screen-capture-protection
        #                 [PSCustomObject]@{
        #                         Name         = 'fEnableScreenCaptureProtect'
        #                         Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
        #                         PropertyType = 'DWord'
        #                         Value        = 1
        #                 }
        #         )
        # }

        ##############################################################
        #  Add Fslogix Settings
        ##############################################################
        if ($Fslogix -eq 'true') {
                $Settings += @(
                        # Enables Fslogix profile containers: https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#enabled
                        [PSCustomObject]@{
                                Name         = 'Enabled'
                                Path         = 'HKLM:\SOFTWARE\Fslogix\Profiles'
                                PropertyType = 'DWord'
                                Value        = 1
                        },
                        # Deletes a local profile if it exists and matches the profile being loaded from VHD: https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#deletelocalprofilewhenvhdshouldapply
                        [PSCustomObject]@{
                                Name         = 'DeleteLocalProfileWhenVHDShouldApply'
                                Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
                                PropertyType = 'DWord'
                                Value        = 1
                        },
                        # The folder created in the Fslogix fileshare will begin with the username instead of the SID: https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#flipflopprofiledirectoryname
                        [PSCustomObject]@{
                                Name         = 'FlipFlopProfileDirectoryName'
                                Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
                                PropertyType = 'DWord'
                                Value        = 1
                        },
                        # Loads FRXShell if there's a failure attaching to, or using an existing profile VHD(X): https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#preventloginwithfailure
                        [PSCustomObject]@{
                                Name         = 'PreventLoginWithFailure'
                                Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
                                PropertyType = 'DWord'
                                Value        = 1
                        },
                        # Loads FRXShell if it's determined a temp profile has been created: https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#preventloginwithtempprofile
                        [PSCustomObject]@{
                                Name         = 'PreventLoginWithTempProfile'
                                Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
                                PropertyType = 'DWord'
                                Value        = 1
                        },
                        # List of file system locations to search for the user's profile VHD(X) file: https://docs.microsoft.com/en-us/fslogix/profile-container-configuration-reference#vhdlocations
                        [PSCustomObject]@{
                                Name         = 'VHDLocations'
                                Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
                                PropertyType = 'MultiString'
                                Value        = $FslogixFileShare
                        },
                        [PSCustomObject]@{
                                Name         = 'VolumeType'
                                Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
                                PropertyType = 'MultiString'
                                Value        = 'vhdx'
                        },
                        [PSCustomObject]@{
                                Name         = 'RemoveOrphanedOSTFilesOnLogoff'
                                Path         = 'HKLM:\SOFTWARE\FSLogix\Profiles'
                                PropertyType = 'DWord'
                                Value        = 1
                        },
                        [PSCustomObject]@{
                                Name         = 'LogFileKeepingPeriod'
                                Path         = 'HKLM:\SOFTWARE\FSLogix\Logging'
                                PropertyType = 'DWord'
                                Value        = 7
                        }
                )
        }
        if ($IdentityServiceProvider -eq "EntraID" -and $Fslogix -eq 'true') {
                $Settings += @(
                        [PSCustomObject]@{
                                Name         = 'CloudKerberosTicketRetrievalEnabled'
                                Path         = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters'
                                PropertyType = 'DWord'
                                Value        = 1
                        },
                        [PSCustomObject]@{
                                Name         = 'LoadCredKeyFromProfile'
                                Path         = 'HKLM:\Software\Policies\Microsoft\AzureADAccount'
                                PropertyType = 'DWord'
                                Value        = 1
                        },
                        [PSCustomObject]@{
                                Name         = $IdentityDomainName
                                Path         = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\domain_realm'
                                PropertyType = 'String'
                                Value        = $fslogixStorageFqdn
                        }

                )
        }

        ##############################################################
        #  Add Microsoft Entra ID Join Setting
        ##############################################################
        if ($IdentityServiceProvider -eq "EntraID") {
                $Settings += @(

                        # Enable PKU2U: https://docs.microsoft.com/en-us/azure/virtual-desktop/troubleshoot-azure-ad-connections#windows-desktop-client
                        [PSCustomObject]@{
                                Name         = 'AllowOnlineID'
                                Path         = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\pku2u'
                                PropertyType = 'DWord'
                                Value        = 1
                        }
                )
        }

        # Set registry settings
        foreach ($Setting in $Settings) {
                # Create registry key(s) if necessary
                if (!(Test-Path -Path $Setting.Path)) {
                        New-Item -Path $Setting.Path -Force
                }

                # Checks for existing registry setting
                $Value = Get-ItemProperty -Path $Setting.Path -Name $Setting.Name -ErrorAction 'SilentlyContinue'
                $LogOutputValue = 'Path: ' + $Setting.Path + ', Name: ' + $Setting.Name + ', PropertyType: ' + $Setting.PropertyType + ', Value: ' + $Setting.Value

                # Creates the registry setting when it does not exist
                if (!$Value) {
                        New-ItemProperty -Path $Setting.Path -Name $Setting.Name -PropertyType $Setting.PropertyType -Value $Setting.Value -Force
                        Write-Log -Message "Added registry setting: $LogOutputValue" -Type 'INFO'
                }
                # Updates the registry setting when it already exists
                elseif ($Value.$($Setting.Name) -ne $Setting.Value) {
                        Set-ItemProperty -Path $Setting.Path -Name $Setting.Name -Value $Setting.Value -Force
                        Write-Log -Message "Updated registry setting: $LogOutputValue" -Type 'INFO'
                }
                # Writes log output when registry setting has the correct value
                else {
                        Write-Log -Message "Registry setting exists with correct value: $LogOutputValue" -Type 'INFO'    
                }
                Start-Sleep -Seconds 1
        }


        ##############################################################
        # Add Defender Exclusions for FSLogix 
        ##############################################################
        # https://docs.microsoft.com/en-us/azure/architecture/example-scenario/wvd/windows-virtual-desktop-fslogix#antivirus-exclusions
        if ($Fslogix -eq 'true') {

                $Files = @(
                        "%ProgramFiles%\FSLogix\Apps\frxdrv.sys",
                        "%ProgramFiles%\FSLogix\Apps\frxdrvvt.sys",
                        "%ProgramFiles%\FSLogix\Apps\frxccd.sys",
                        "%TEMP%\*.VHD",
                        "%TEMP%\*.VHDX",
                        "%Windir%\TEMP\*.VHD",
                        "%Windir%\TEMP\*.VHDX"
                        "$FslogixFileShareName\*.VHD"
                        "$FslogixFileShareName\*.VHDX"
                )

                foreach ($File in $Files) {
                        Add-MpPreference -ExclusionPath $File
                }
                Write-Log -Message 'Enabled Defender exlusions for FSLogix paths' -Type 'INFO'

                $Processes = @(
                        "%ProgramFiles%\FSLogix\Apps\frxccd.exe",
                        "%ProgramFiles%\FSLogix\Apps\frxccds.exe",
                        "%ProgramFiles%\FSLogix\Apps\frxsvc.exe"
                )

                foreach ($Process in $Processes) {
                        Add-MpPreference -ExclusionProcess $Process
                }
                Write-Log -Message 'Enabled Defender exlusions for FSLogix processes' -Type 'INFO'
        }


        ##############################################################
        #  Install the AVD Agent
        ##############################################################
        # Disabling this method for installing the AVD agent until EntraID Join can completed successfully
        $BootInstaller = 'AVD-Bootloader.msi'
        Get-WebFile -FileName $BootInstaller -URL 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'
        Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $BootInstaller /quiet /qn /norestart /passive" -Wait -Passthru
        Write-Log -Message 'Installed AVD Bootloader' -Type 'INFO'
        Start-Sleep -Seconds 5

        $AgentInstaller = 'AVD-Agent.msi'
        Get-WebFile -FileName $AgentInstaller -URL 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv'
        Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $AgentInstaller /quiet /qn /norestart /passive REGISTRATIONTOKEN=$HostPoolRegistrationToken" -Wait -PassThru
        Write-Log -Message 'Installed AVD Agent' -Type 'INFO'
        Start-Sleep -Seconds 5

        ##############################################################
        #  Restart VM
        ##############################################################
        Write-Log -Message 'Set-SessionHostConfiguration finished, restarting' -Type 'INFO'
        Write-Log -Message 'Lubon session host script' -Type 'INFO'
        Start-Process -FilePath 'shutdown' -ArgumentList '/r /t 30'
        }
        catch {
        Write-Log -Message $_ -Type 'ERROR'
        throw
}
