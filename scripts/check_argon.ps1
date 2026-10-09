$url = "http://127.0.0.1:7070/health"
try {
    $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 3
    Write-Output "argon responded: $resp"
} catch {
    Write-Output "no argon health response at $url - $($_.Exception.Message)"
}
