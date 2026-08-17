#Check if there is a new version of Outlook available. If there is, store the new version number and send a notification.

$req = [System.Net.WebRequest]::Create("https://go.microsoft.com/fwlink/?linkid=2195164")
$req.Method = "HEAD"
$req.AllowAutoRedirect = $false
$resp = $req.GetResponse()
$resp.Headers["Location"] -match '/(\d+\.\d+\.\d+\.\d+)/' | Out-Null
$latest = $Matches[1]

$storedPath = "C:\scripts\version.txt"
$stored = Get-Content $storedPath -ErrorAction SilentlyContinue

if ($stored -ne $latest) {
    Set-Content $storedPath $latest
    # Send email, Teams webhook, etc.
    Write-Host $latest
} else { Write-Host "No new version $latest" }