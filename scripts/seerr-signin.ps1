# One-time Seerr sign-in with Jellyfin (uses hostname "jellyfin", the Docker container name).
# Your password is read securely and sent only to your local Seerr (http://localhost:5055).

$username = Read-Host 'Jellyfin username [bhanu]'
if (-not $username) { $username = 'bhanu' }
$email = Read-Host 'Email for Seerr (any address, used as a label)'
$secure = Read-Host 'Jellyfin password' -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

$body = @{
    username   = $username
    password   = $password
    email      = $email
    hostname   = 'jellyfin'
    port       = 8096
    useSsl     = $false
    urlBase    = ''
    serverType = 2   # 2 = Jellyfin
} | ConvertTo-Json

try {
    $r = Invoke-RestMethod 'http://localhost:5055/api/v1/auth/jellyfin' -Method Post -ContentType 'application/json' -Body $body
    Write-Host "Signed in to Seerr as $($r.displayName) (admin). Tell Claude it worked." -ForegroundColor Green
} catch {
    $resp = $_.Exception.Response; $t = ''
    if ($resp) { $t = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd() }
    Write-Host "Sign-in failed: HTTP $([int]$resp.StatusCode) $t" -ForegroundColor Red
    if ($t -match 'INVALID_CREDENTIALS|401') { Write-Host 'Username or password is wrong - check them by logging in at http://localhost:8096' }
} finally {
    $password = $null
}
