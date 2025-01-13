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

# Customize the following variables
$languagePacks = "nl-NL","nl-BE","fr-BE","de-DE"
$defaultLanguage = "nl-BE"

# Define Geo Id
if($defaultLanguage -eq "nl-BE"){
    $geoId = '21'
} 
elseif ($defaultLanguage -eq "nl-NL") {
    $geoId = "176"
}


# Start powershell logging
$SaveVerbosePreference = $VerbosePreference
$VerbosePreference = 'continue'
$LogTime = Get-Date
Start-Transcript -Path "C:\Windows\temp\InstallLanguages_log.txt" -Append
Write-Host "################# New Script Run #################"
Write-host "Current time (UTC-0): $LogTime"
Write-host "The following language packs will be installed"
Write-Host "$languagePacks"

Set-TimeZone -Id "Romance Standard Time" -PassThru

#Disable Language Pack Cleanup (do not re-enable)
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\AppxDeploymentClient\" -TaskName "Pre-staged app cleanup" | Out-Null

# Download and install the Language Packs
foreach ($language in $languagePacks)
{
Write-Host "Installing Language Pack for: $language"
Install-Language $language
Write-Host "Installing Language Pack for: $language completed."
}

if ($defaultLanguage -eq $null)
{
Write-Host "Default Language not configured."
}
else
{
Write-Host "Setting default Language to: $defaultLanguage"
Set-SystemPreferredUILanguage $defaultLanguage
}

#Set all regional setting to default language
Set-Culture -CultureInfo $defaultLanguage
Set-WinSystemLocale -SystemLocale $defaultLanguage
Set-WinUILanguageOverride -Language $defaultLanguage
Set-WinUserLanguageList -LanguageList $defaultLanguage -Force
Set-WinHomeLocation -GeoId $geoId

# Update the SYSTEM user registry with extra settings for nl-BE before copying the settings to new users
if($defaultLanguage -eq "nl-BE"){
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

# End Logging
Stop-Transcript
$VerbosePreference = $SaveVerbosePreference
