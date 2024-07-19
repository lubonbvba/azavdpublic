#Install BgInfo with custom config file

# Define the URLs and file paths
$url = "https://download.sysinternals.com/files/BGInfo.zip"
$urlConfig = "https://raw.githubusercontent.com/lubonbvba/azavdpublic/main/Scripts/BgInfo/config.bgi"
$zipPath = "$env:TEMP\BGInfo.zip"
$extractPath = "$env:TEMP\BGInfo"
$destinationPath = "C:\Program Files\Bginfo"
$configDestinationPath = "$destinationPath\config.bgi"
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$regName = "BGInfo"
$regValue = "$destinationPath\Bginfo64.exe $configDestinationPath /NOLICPROMPT /timer:0"

# Create the destination directory if it doesn't exist
if (-not (Test-Path -Path $destinationPath)) {
    New-Item -ItemType Directory -Path $destinationPath -Force
}

# Download the zip file
Invoke-WebRequest -Uri $url -OutFile $zipPath

# Download the config file
Invoke-WebRequest -Uri $urlConfig -OutFile $configDestinationPath

# Extract the zip file
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# Copy Bginfo64.exe to the destination path
$sourceFile = Join-Path -Path $extractPath -ChildPath "Bginfo64.exe"
Copy-Item -Path $sourceFile -Destination $destinationPath -Force

# Clean up the temporary files
Remove-Item -Path $zipPath -Force
Remove-Item -Path $configPath -Force
Remove-Item -Path $extractPath -Recurse -Force

# Create the registry key to run BGInfo at startup
New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force

Write-Output "Bginfo64.exe and the config file have been copied to $destinationPath"