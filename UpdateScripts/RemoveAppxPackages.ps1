#Run the clean APPX Packages from vdot again
#After windows updates some apps seem to be installed again like mail client and dev home

# Define the list of AppxPackages to disable
$appxPackagesToDisable = @(
"Microsoft.Windows.DevHome",
"Microsoft.OutlookForWindows"
)


foreach ($package in $appxPackagesToDisable)
{
    try
    {
        Write-Output "Removing Provisioned Package $package"
        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$package*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    }
    catch
    {
        Write-Warning "Failed to remove provisioned Appx Package $package - $($_.Exception.Message)"
    }

    try
    {
        Write-Output "Attempting to remove [All Users] $package"
        Get-AppxPackage -AllUsers -Name "*$package*" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

        Write-Output "Attempting to remove $package for the current user"
        Get-AppxPackage -Name "*$package*" | Remove-AppxPackage -ErrorAction SilentlyContinue | Out-Null
    }
    catch
    {
        Write-Warning "Failed to remove Appx Package $package for all or current users - $($_.Exception.Message)"
    }
}