# Run elevated (as Administrator)

$deletedPath = "C:\Program Files\WindowsApps\DeletedAllUserPackages"

# Step 1: Get all currently active/installed package full names
$activePackages = Get-AppxPackage -AllUsers | Select-Object -ExpandProperty PackageFullName

# Step 2: Enumerate subfolders and cross-check (no ownership change yet)
$toDelete = @()
$toKeep   = @()

Get-ChildItem -Path $deletedPath -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($activePackages -contains $_.Name) {
        $toKeep += $_.Name
    } else {
        $toDelete += $_
    }
}

# Step 3: Report before doing anything
Write-Host "`n=== SAFE TO DELETE (not active) ===" -ForegroundColor Green
$toDelete | ForEach-Object { Write-Host "  $($_.Name)" }

Write-Host "`n=== KEEPING (still active) ===" -ForegroundColor Yellow
$toKeep | ForEach-Object { Write-Host "  $_" }

Write-Host "`nTotal to delete: $($toDelete.Count) folders"
Write-Host "Total to keep:   $($toKeep.Count) folders"

# Helper: convert path to long-path prefix to bypass MAX_PATH
function Convert-ToLongPath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $Path }
    if ($Path.StartsWith('\\?\')) { return $Path }
    if ($Path.StartsWith('\\')) {
        # UNC path: \\server\share -> \\?\UNC\server\share
        return '\\?\UNC\' + $Path.Substring(2)
    } else {
        # Local path: C:\path -> \\?\C:\path
        return '\\?\' + $Path
    }
}

# Step 4: Proceed with deletion (no prompt)
if ($toDelete.Count -eq 0) {
    Write-Host "`nNothing to delete." -ForegroundColor Cyan
} else {
    $toDelete | ForEach-Object {
        $folderPath = $_.FullName
        Write-Host "`nProcessing: $folderPath" -ForegroundColor Cyan

        $longFolderPath = Convert-ToLongPath $folderPath

        # Take ownership only on this specific subfolder
        takeown /F $longFolderPath /R /D Y | Out-Null
        icacls $longFolderPath /grant "Administrators:F" /T /C /Q | Out-Null

        # Now delete it
        Remove-Item -Path $longFolderPath -Recurse -Force -ErrorAction SilentlyContinue
        
        if (Test-Path $longFolderPath) {
            Write-Host "  WARNING: Could not fully remove $folderPath" -ForegroundColor Red
        } else {
            Write-Host "  Removed successfully." -ForegroundColor Green
        }
    }
    Write-Host "`nDone." -ForegroundColor Cyan
}