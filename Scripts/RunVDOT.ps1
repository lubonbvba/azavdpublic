#Run VDOT

##############################################################
#  Run the Virtual Desktop Optimization Tool (VDOT)
##############################################################
# https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool

# Download VDOT
$URL = 'https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool/archive/refs/heads/main.zip'
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
    "Microsoft.OutlookForWindows",
    "Microsoft.People",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.SkypeApp",
    "Microsoft.WinDbg.Fast",
    "Microsoft.Windows.DevHome",
    "microsoft.windowscommunicationsapps",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
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
# Run VDOT and reboot
& .\VDOT\Virtual-Desktop-Optimization-Tool-main\Windows_VDOT.ps1 -Optimizations AppxPackages, ScheduledTasks, DefaultUserSettings, LocalPolicy, Autologgers, Services, NetworkOptimizations -AdvancedOptimizations 'Edge', 'RemoveLegacyIE' -AcceptEULA -Restart
