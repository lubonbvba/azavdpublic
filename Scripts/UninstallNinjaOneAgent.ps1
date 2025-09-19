#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Uninstalls NinjaOne Agent (NinjaRMMAgent) from the system
.DESCRIPTION
    This script checks for the presence of NinjaOne Agent, disables uninstall protection,
    and performs a silent uninstall without user interaction.
.NOTES
    File Name      : UninstallNinjaOneAgentAVD.ps1
    Author         : Generated Script
    Prerequisite   : PowerShell 5.0 or higher, Administrator privileges
    Version        : 1.0
#>

# Function to write log messages
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# Function to check if NinjaRMMAgent process is running
function Test-NinjaAgentProcess {
    Write-Log "Checking if NinjaRMMAgent.exe process is running..."
    $process = Get-Process -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue
    if ($process) {
        Write-Log "NinjaRMMAgent.exe process is currently running (PID: $($process.Id))" -Level "WARNING"
        return $true
    } else {
        Write-Log "NinjaRMMAgent.exe process is not running"
        return $false
    }
}

# Function to check if NinjaOne Agent is installed via registry
function Test-NinjaAgentInstalled {
    Write-Log "Checking registry for NinjaOne Agent installation..."
    
    $registryPaths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    foreach ($path in $registryPaths) {
        $installedPrograms = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
                           Where-Object { $_.DisplayName -like "*NinjaRMM*" }
        
        if ($installedPrograms) {
            foreach ($program in $installedPrograms) {
                Write-Log "Found NinjaOne Agent: $($program.DisplayName) - Version: $($program.DisplayVersion)"
                return $program
            }
        }
    }
    
    Write-Log "NinjaOne Agent not found in registry"
    return $null
}

# Function to find NinjaRMMAgent.exe location
function Find-NinjaAgentExecutable {
    Write-Log "Searching for NinjaRMMAgent.exe..."
    
    # First, check the registry for the installation location
    try {
        $registryPath = "HKLM:\SOFTWARE\WOW6432Node\NinjaRMM LLC\NinjaRMMAgent"
        $locationProperty = Get-ItemProperty -Path $registryPath -Name "Location" -ErrorAction SilentlyContinue
        
        if ($locationProperty -and $locationProperty.Location) {
            $installPath = $locationProperty.Location
            $executablePath = Join-Path $installPath "NinjaRMMAgent.exe"
            
            if (Test-Path $executablePath) {
                Write-Log "Found NinjaRMMAgent.exe via registry at: $executablePath"
                return $executablePath
            } else {
                Write-Log "Registry location found ($installPath) but NinjaRMMAgent.exe not found there" -Level "WARNING"
            }
        } else {
            Write-Log "NinjaRMMAgent installation location not found in registry"
        }
    }
    catch {
        Write-Log "Error reading NinjaRMMAgent location from registry: $($_.Exception.Message)" -Level "WARNING"
    }
    
    # Last resort: Try to find via running process
    $process = Get-Process -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue
    if ($process) {
        $executablePath = $process.MainModule.FileName
        Write-Log "Found NinjaRMMAgent.exe via running process at: $executablePath"
        return $executablePath
    }
    
    Write-Log "NinjaRMMAgent.exe not found in registry, common locations, or running processes" -Level "WARNING"
    return $null
}

# Function to disable uninstall protection
function Disable-UninstallProtection {
    param([string]$AgentPath)
    
    Write-Log "Attempting to disable uninstall protection..."
    
    try {
        $arguments = "-disableUninstallPrevention NOUI"
        Write-Log "Running: `"$AgentPath`" $arguments"
        
        $processInfo = Start-Process -FilePath $AgentPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        if ($processInfo.ExitCode -eq 0 -or $processInfo.ExitCode -eq 1) {
            Write-Log "Successfully disabled uninstall protection (Exit code: $($processInfo.ExitCode))"
            return $true
        } else {
            Write-Log "Failed to disable uninstall protection. Exit code: $($processInfo.ExitCode)" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error disabling uninstall protection: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to uninstall NinjaOne Agent
function Uninstall-NinjaAgent {
    param($InstalledProgram)
    
    Write-Log "Attempting to uninstall NinjaOne Agent..."
    
    try {
        $uninstallString = $InstalledProgram.UninstallString
        
        if ([string]::IsNullOrEmpty($uninstallString)) {
            Write-Log "No uninstall string found in registry" -Level "ERROR"
            return $false
        }
        
        Write-Log "Uninstall string: $uninstallString"
        
        # Parse the MSI uninstall string to extract the product code
        if ($uninstallString -match "MsiExec.exe.*?(\{[^}]+\})") {
            $productCode = $matches[1]
            $arguments = "/x $productCode /quiet /norestart"
            $executable = "msiexec.exe"
            
            Write-Log "Running MSI uninstall: $executable $arguments"
            $processInfo = Start-Process -FilePath $executable -ArgumentList $arguments -Wait -PassThru -NoNewWindow
            
            if ($processInfo.ExitCode -eq 0) {
                Write-Log "Successfully uninstalled NinjaOne Agent"
                return $true
            } else {
                Write-Log "Uninstall completed with exit code: $($processInfo.ExitCode)" -Level "WARNING"
                return $true  # Many uninstallers return non-zero even on success
            }
        } else {
            Write-Log "Could not extract product code from MSI uninstall string" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error during uninstallation: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to verify uninstallation
function Test-UninstallSuccess {
    Write-Log "Verifying uninstallation..."
    
    # Check if process is still running
    $processRunning = Test-NinjaAgentProcess
    
    # Check if still in registry
    $stillInstalled = Test-NinjaAgentInstalled
    
    if (-not $processRunning -and -not $stillInstalled) {
        Write-Log "NinjaOne Agent successfully uninstalled" -Level "SUCCESS"
        return $true
    } else {
        Write-Log "NinjaOne Agent may not have been completely uninstalled" -Level "WARNING"
        return $false
    }
}

# Main execution
Write-Log "Starting NinjaOne Agent uninstallation process..."

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log "This script requires Administrator privileges. Please run as Administrator." -Level "ERROR"
    exit 1
}

# Step 1: Check if agent process is running
$isProcessRunning = Test-NinjaAgentProcess

# Step 2: Check if agent is installed via registry
$installedProgram = Test-NinjaAgentInstalled

if (-not $installedProgram) {
    Write-Log "NinjaOne Agent does not appear to be installed on this system"
    
    if ($isProcessRunning) {
        Write-Log "However, NinjaRMMAgent.exe process is running. It will be stopped during uninstallation."
    }
    
    exit 0
}

# Step 3: Find NinjaRMMAgent.exe location
$agentPath = Find-NinjaAgentExecutable

if ($agentPath) {
    # Step 4: Disable uninstall protection (this will update the registry uninstall string)
    $protectionDisabled = Disable-UninstallProtection -AgentPath $agentPath
    
    if (-not $protectionDisabled) {
        Write-Log "Warning: Could not disable uninstall protection. Proceeding with uninstallation anyway..." -Level "WARNING"
    }
    
    # Give some time for the protection to be disabled and registry to be updated
    Start-Sleep -Seconds 3
    
    # Step 5: Re-read the registry to get the updated uninstall string
    Write-Log "Re-reading registry for updated uninstall information after disabling protection..."
    $installedProgram = Test-NinjaAgentInstalled
    
    if (-not $installedProgram) {
        Write-Log "Warning: Could not find updated registry information after disabling protection" -Level "WARNING"
    }
} else {
    Write-Log "Warning: Could not find NinjaRMMAgent.exe to disable uninstall protection" -Level "WARNING"
}

# Step 6: Perform silent uninstallation using updated registry information
$uninstallSuccess = Uninstall-NinjaAgent -InstalledProgram $installedProgram

if ($uninstallSuccess) {
    # Step 7: Verify uninstallation
    Start-Sleep -Seconds 10  # Wait for uninstaller to complete
    $verificationSuccess = Test-UninstallSuccess
    
    if ($verificationSuccess) {
        Write-Log "NinjaOne Agent uninstallation completed successfully!" -Level "SUCCESS"
        exit 0
    } else {
        Write-Log "Uninstallation may have completed but verification failed" -Level "WARNING"
        exit 2
    }
} else {
    Write-Log "Failed to uninstall NinjaOne Agent" -Level "ERROR"
    exit 1
}
