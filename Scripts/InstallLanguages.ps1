<#
.SYNOPSIS
Script to install and configure Language Packs via Install-Language

.DESCRIPTION
This script will use the new cmdlets for installing and configuring language packs See https://docs.microsoft.com/nl-nl/powershell/module/languagepackmanagement/?view=windowsserver2022-ps for more information. For this script to work you need at least Wind

.PARAMETER languagePack
This is the language code for the language(s) you want to install

.PARAMETER defaultLanguage
This is the language code for the default language you want to configure

.DOCS
Available languages: https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/available-language-packs-for-windows?view=windows-11
New PowerShell cmdlets: https://docs.microsoft.com/nl-nl/powershell/module/languagepackmanagement/?view=windowsserver2022-ps

.LINK
https://github.com/StefanDingemanse/NMW/edit/main/scripted-actions/windows-script/Install%20languages.ps1
#>

param(
    [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Specify Windows language packs to install")]
    [ValidateSet("nl", "fr", "de")]
    [string[]]$languagePacks = @("nl", "fr"),

    [Parameter(Mandatory = $false, Position = 2, HelpMessage = "Specify default Windows language for new users")]
    [ValidateSet("nl-BE", "nl-NL",  "en", "fr", "de")]
    [string]$defaultLanguage = "nl-BE"
)

# Define mapping from short code to full language code
$languageMap = @{
    "nl" = @("nl-NL", "nl-BE")
    "fr" = "fr-BE"
    "en" = "en-BE"
    "de" = "de-DE"
}

# Map $languagePacks to full codes
$languagePacksToInstall = $languagePacks | ForEach-Object { $languageMap[$_] }

# Map $defaultLanguage to full code if needed
if ($languageMap.ContainsKey($defaultLanguage)) {
    $defaultLanguageToSet = $languageMap[$defaultLanguage]
} else {
    $defaultLanguageToSet = $defaultLanguage
}

# Define Geo Id
$geoId = "21" #Set Default GeoId to nl-BE
if($defaultLanguage -eq "nl-NL"){
    $geoId = '176'
}

# Start powershell logging
$SaveVerbosePreference = $VerbosePreference
$VerbosePreference = 'continue'
$LogTime = Get-Date
Start-Transcript -Path "C:\Windows\temp\InstallLanguages_log.txt" -Append
Write-Host "################# New Script Run #################"
Write-host "Current time (UTC-0): $LogTime"
Write-host "The following language packs will be installed"
Write-Host "$languagePacksToInstall"

Set-TimeZone -Id "Romance Standard Time" -PassThru

#Disable Language Pack Cleanup (do not re-enable)
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup" | Out-Null

# Initialize stopwatch for performance tracking
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Download and install the Language Packs with retry logic
foreach ($language in $languagePacksToInstall)
{
    Write-Host "Installing Language Pack for: $language"
    $i = 1
    while ($i -le 5) {
        try {
            Write-Host "Install language packs - Attempt: $i"
            Install-Language $language -ErrorAction Stop
            Write-Host "Installing Language Pack for: $language completed."
            break
        }
        catch {
            Write-Host "Install language packs - Exception occurred on attempt $i"
            Write-Host $_.Exception.Message
            if ($i -eq 5) {
                Write-Host "Failed to install $language after 5 attempts. Moving to next language."
                break
            }
        }
        $i++
    }
}

# Stop timing and report results
$stopwatch.Stop()
$elapsedTime = $stopwatch.Elapsed
Write-Host "Install language packs - Exit Code: $LASTEXITCODE"
Write-Host "Ending: Install language packs - Time taken: $elapsedTime"

# NOTE: Do NOT call Set-SystemPreferredUILanguage with the target language. Per Microsoft docs
# this cmdlet sets the preferred UI language for the system itself, including the Welcome screen
# and system accounts (SYSTEM, Local Service, Network Service) - not just new user accounts, so
# calling it would put SYSTEM back on $defaultLanguageToSet.
if ($defaultLanguage -eq $null)
{
Write-Host "Default Language not configured."
}
else
{
Write-Host "Leaving system-wide preferred UI language on en-US (skipping Set-SystemPreferredUILanguage) so SYSTEM/perf counters stay English. New users will still get: $defaultLanguageToSet"
}

#Set all regional setting to default language for the current (build) user - this gets copied to
#the default new-user profile below via Copy-UserInternationalSettingsToSystem -NewUser $true
Set-Culture -CultureInfo $defaultLanguageToSet
# NOTE: Do NOT change the system locale (Set-WinSystemLocale). Azure Monitor / AVD Insights
# relies on English-localized performance counter names to parse metrics; changing the
# system locale breaks that parsing. Keep the system locale on en-US and only localize
# the UI language, culture and formats below.
Set-WinUILanguageOverride -Language $defaultLanguageToSet
Set-WinUserLanguageList -LanguageList $defaultLanguageToSet -Force
Set-WinHomeLocation -GeoId $geoId

# Update the SYSTEM user registry with extra settings for nl-BE before copying the settings to new users
if($defaultLanguageToSet -eq "nl-BE"){
    $settings = @{
    "Locale" = "00000813"
    "LocaleName" = "nl-BE"
    "sDate" = "/"
    "sShortDate" = "d/MM/yyyy"
    "iCountry" = "32"
    "iLZero" = "1"
    "iTLZero" = "0"
    }

    # Loop through each setting and update the registry
    foreach ($key in $settings.Keys) {
        $name = $key
        $value = $settings[$key]
        # Modify the registry value
        Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\International" -Name $name -Value $value
}
}

Copy-UserInternationalSettingsToSystem -WelcomeScreen $false -NewUser $True

# --- Reset the account actually EXECUTING this script back to English ---
# This script typically runs as SYSTEM (Custom Script Extension / scripted action). The Set-Culture /
# Set-WinUILanguageOverride / Set-WinUserLanguageList calls above modified the executing account's OWN
# live registry hive (HKCU while running as SYSTEM *is* SYSTEM's profile) to $defaultLanguageToSet, so
# that Copy-UserInternationalSettingsToSystem -NewUser could propagate it into HKU\.DEFAULT for new
# users. That leaves SYSTEM's own hive on $defaultLanguageToSet too - which is what caused Get-Counter
# (and Azure Monitor/AVD Insights perf counters) to return localized names as SYSTEM. Now that propagation to .DEFAULT is done, force the
# executing account's own culture/UI language/LocaleName back to English.
$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
if ($currentIdentity.IsSystem) {
    Write-Host "Script is running as SYSTEM - resetting SYSTEM's own locale/UI language back to en-US now that $defaultLanguageToSet has been propagated to the default new-user profile."
    Set-Culture -CultureInfo "en-US"
    Set-WinUILanguageOverride -Language "en-US"
    Set-WinUserLanguageList -LanguageList "en-US" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "LocaleName" -Value "en-US"
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name "Locale" -Value "00000409"
}
else {
    Write-Host "Script is not running as SYSTEM ($($currentIdentity.Name)) - skipping SYSTEM locale reset."
}

# End Logging
Stop-Transcript
$VerbosePreference = $SaveVerbosePreference
