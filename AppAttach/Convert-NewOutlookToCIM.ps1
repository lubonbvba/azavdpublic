<#
.SYNOPSIS
    Downloads the latest New Outlook version and converts it to a CIM package for App Attach.

.DESCRIPTION
    This script automates the process of:
    1. Downloading the latest New Outlook MSIX package from Microsoft
    2. Converting the MSIX package to a CIM package using MSIXMGR tool
    3. Creating the package ready for Azure Virtual Desktop App Attach

.PARAMETER DownloadPath
    The path where the MSIX package will be downloaded. Default: C:\temp

.PARAMETER DestinationPath
    The path where the CIM package will be created. Default: C:\temp\NewOutlook23H2

.PARAMETER MsixMgrPath
    The path to the msixmgr.exe tool. Default: .\msixmgr.exe

.PARAMETER RootDirectory
    The root directory name for the CIM package. Default: apps

.EXAMPLE
    .\Convert-NewOutlookToCIM.ps1
    Downloads and converts New Outlook using default paths.

.EXAMPLE
    .\Convert-NewOutlookToCIM.ps1 -DownloadPath "D:\Downloads" -DestinationPath "D:\CIMPackages\NewOutlook"
    Downloads and converts New Outlook using custom paths.

.NOTES
    Requires msixmgr.exe tool to be available.
    Administrative privileges are recommended for best results.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DownloadPath = "C:\temp2",
    
    [Parameter(Mandatory = $false)]
    [string]$DestinationPath = "C:\temp2\NewOutlook23H2-$(Get-Date -Format 'ddMMyy')",
    
    [Parameter(Mandatory = $false)]
    [string]$MsixMgrPath = "C:\temp2\msixmgr\msixmgr.exe",
    
    [Parameter(Mandatory = $false)]
    [string]$RootDirectory = "apps"
)

# New Outlook download URL
$outlookDownloadUrl = "https://go.microsoft.com/fwlink/?linkid=2195164"
$msixFileName = "Microsoft.OutlookForWindows_x64.msix"
$cimFileName = "newoutlook.cim"

# Full paths
$msixFullPath = Join-Path -Path $DownloadPath -ChildPath $msixFileName
$cimFullPath = Join-Path -Path $DestinationPath -ChildPath $cimFileName

# Function to write colored output
function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    switch ($Type) {
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Error" { Write-Host $Message -ForegroundColor Red }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        default { Write-Host $Message -ForegroundColor Cyan }
    }
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to download and extract msixmgr tool
function Get-MsixMgr {
    param(
        [string]$ToolPath
    )
    
    Write-Status "MSIXMGR tool not found. Downloading..." "Info"
    
    $msixMgrUrl = "https://aka.ms/msixmgr"
    $toolDirectory = Split-Path -Path $ToolPath -Parent
    
    # Ensure we're using absolute paths
    if (-not [System.IO.Path]::IsPathRooted($toolDirectory)) {
        $toolDirectory = Join-Path -Path (Get-Location) -ChildPath $toolDirectory
    }
    
    $zipPath = Join-Path -Path $toolDirectory -ChildPath "msixmgr.zip"
    
    try {
        # Create directory if it doesn't exist
        if (-not (Test-Path -Path $toolDirectory)) {
            New-Item -Path $toolDirectory -ItemType Directory -Force | Out-Null
            Write-Status "Created msixmgr directory: $toolDirectory" "Success"
        }
        
        # Download msixmgr zip
        Write-Status "Downloading from: $msixMgrUrl" "Info"
        $originalProgressPreference = $ProgressPreference
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $msixMgrUrl -OutFile $zipPath -UseBasicParsing
        } finally {
            $ProgressPreference = $originalProgressPreference
        }
        
        if (-not (Test-Path -Path $zipPath)) {
            throw "Failed to download msixmgr.zip"
        }
        
        Write-Status "Extracting msixmgr tool and dependencies..." "Info"
        
        # Create a temporary extraction folder
        $tempExtractPath = Join-Path -Path $toolDirectory -ChildPath "msixmgr_temp"
        if (Test-Path -Path $tempExtractPath) {
            Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Extract the zip file to temp location
        Expand-Archive -Path $zipPath -DestinationPath $tempExtractPath -Force
        
        # Look specifically for x64 version of msixmgr.exe
        $x64Path = Join-Path -Path $tempExtractPath -ChildPath "x64"
        
        if (-not (Test-Path -Path $x64Path)) {
            throw "x64 folder not found in msixmgr package"
        }
        
        $extractedExe = Join-Path -Path $x64Path -ChildPath "msixmgr.exe"
        
        if (Test-Path -Path $extractedExe) {
            # Copy all files from x64 directory (exe + DLLs) to the tool directory
            Write-Status "Copying x64 msixmgr.exe and dependencies..." "Info"
            Get-ChildItem -Path $x64Path -File | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $toolDirectory -Force
            }
            
            # Verify msixmgr.exe is in the expected location
            if (-not (Test-Path -Path $ToolPath)) {
                throw "msixmgr.exe not found at expected location after extraction"
            }
            
            Write-Status "MSIXMGR tool and dependencies extracted successfully" "Success"
        } else {
            throw "msixmgr.exe not found in x64 folder"
        }
        
        # Clean up temp extraction folder and zip file
        if (Test-Path -Path $tempExtractPath) {
            Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -Path $zipPath) {
            Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        }
        
    } catch {
        throw "Failed to download or extract msixmgr tool: $($_.Exception.Message)"
    }
}

# Main script execution
try {
    Write-Status "=====================================" "Info"
    Write-Status "New Outlook to CIM Converter" "Info"
    Write-Status "=====================================" "Info"
    Write-Host ""

    # Check for administrative privileges
    if (-not (Test-Administrator)) {
        Write-Status "WARNING: Script is not running with administrative privileges." "Warning"
        Write-Status "Some operations may fail without administrator rights." "Warning"
        Write-Host ""
    }

    # Verify MSIXMGR tool exists, download if necessary
    Write-Status "Checking for MSIXMGR tool..." "Info"
    if (-not (Test-Path -Path $MsixMgrPath)) {
        Get-MsixMgr -ToolPath $MsixMgrPath
    }
    
    if (-not (Test-Path -Path $MsixMgrPath)) {
        throw "MSIXMGR tool not found at: $MsixMgrPath after download attempt."
    }
    Write-Status "MSIXMGR tool ready at: $MsixMgrPath" "Success"
    Write-Host ""

    # Create download directory if it doesn't exist
    Write-Status "Preparing directories..." "Info"
    if (-not (Test-Path -Path $DownloadPath)) {
        New-Item -Path $DownloadPath -ItemType Directory -Force | Out-Null
        Write-Status "Created download directory: $DownloadPath" "Success"
    }

    # Create destination directory if it doesn't exist
    if (-not (Test-Path -Path $DestinationPath)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        Write-Status "Created destination directory: $DestinationPath" "Success"
    }
    Write-Host ""

    # Download New Outlook MSIX package
    Write-Status "Downloading New Outlook MSIX package..." "Info"
    Write-Status "Source: $outlookDownloadUrl" "Info"
    Write-Status "Destination: $msixFullPath" "Info"
    
    try {
        # Use Invoke-WebRequest to download with progress
        $originalProgressPreference = $ProgressPreference
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $outlookDownloadUrl -OutFile $msixFullPath -UseBasicParsing
        } finally {
            $ProgressPreference = $originalProgressPreference
        }
        
        if (Test-Path -Path $msixFullPath) {
            $fileSize = (Get-Item $msixFullPath).Length / 1MB
            Write-Status "Download completed successfully! Size: $([math]::Round($fileSize, 2)) MB" "Success"
        } else {
            throw "Download failed - file not found after download attempt."
        }
    } catch {
        throw "Failed to download New Outlook package: $($_.Exception.Message)"
    }
    Write-Host ""

    # Convert MSIX to CIM using MSIXMGR
    Write-Status "Converting MSIX to CIM package..." "Info"
    Write-Status "This may take several minutes..." "Info"
    
    $msixMgrArgs = @(
        "-Unpack"
        "-packagePath", $msixFullPath
        "-destination", $cimFullPath
        "-applyACLs"
        "-create"
        "-fileType", "cim"
        "-rootDirectory", $RootDirectory
    )
    
    Write-Status "Executing: $MsixMgrPath $($msixMgrArgs -join ' ')" "Info"
    Write-Host ""
    
    try {
        # Create temporary files for capturing output
        $stdOutFile = [System.IO.Path]::GetTempFileName()
        $stdErrFile = [System.IO.Path]::GetTempFileName()
        
        try {
            $process = Start-Process -FilePath $MsixMgrPath -ArgumentList $msixMgrArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdOutFile -RedirectStandardError $stdErrFile
            
            # Read error output if process failed
            if ($process.ExitCode -ne 0) {
                $errorOutput = Get-Content $stdErrFile -Raw
                if ($errorOutput) {
                    Write-Status "MSIXMGR Error Output:" "Error"
                    Write-Status $errorOutput "Error"
                }
                throw "MSIXMGR exited with code: $($process.ExitCode)"
            }
            
            Write-Host ""
            Write-Status "Conversion completed successfully!" "Success"
                
            if (Test-Path -Path $cimFullPath) {
                $cimSize = (Get-Item $cimFullPath).Length / 1MB
                Write-Status "CIM package created: $cimFullPath" "Success"
                Write-Status "CIM package size: $([math]::Round($cimSize, 2)) MB" "Success"
            }
        } finally {
            # Clean up temp files
            if ($stdOutFile -and (Test-Path -Path $stdOutFile -ErrorAction SilentlyContinue)) {
                Remove-Item $stdOutFile -ErrorAction SilentlyContinue
            }
            if ($stdErrFile -and (Test-Path -Path $stdErrFile -ErrorAction SilentlyContinue)) {
                Remove-Item $stdErrFile -ErrorAction SilentlyContinue
            }
        }
    } catch {
        throw "Failed to convert MSIX to CIM: $($_.Exception.Message)"
    }
    
    Write-Host ""
    Write-Status "=====================================" "Info"
    Write-Status "Process completed successfully!" "Success"
    Write-Status "=====================================" "Info"
    Write-Host ""
    Write-Status "MSIX Package: $msixFullPath" "Info"
    Write-Status "CIM Package: $cimFullPath" "Info"
    Write-Host ""
    Write-Status "The CIM package is ready to use for App Attach in Azure Virtual Desktop." "Success"
    
} catch {
    Write-Host ""
    Write-Status "=====================================" "Error"
    Write-Status "ERROR: $($_.Exception.Message)" "Error"
    Write-Status "=====================================" "Error"
    Write-Host ""
    exit 1
}
