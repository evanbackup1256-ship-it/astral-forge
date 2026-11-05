# Watches out/ for rbxtsc rebuilds and pushes the tree into Studio through Azul.
# Debounces bursts so a full recompile triggers one build, not hundreds.
# Logs every push to out/.azul-watch.log so sync health is visible.
$root = "C:\dev\astral-forge"
$out = Join-Path $root "out"
$log = Join-Path $out ".azul-watch.log"
$pending = $true # push once at startup so Studio starts in sync

$watcher = New-Object System.IO.FileSystemWatcher $out, "*.luau"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$action = { $script:pending = $true }
Register-ObjectEvent $watcher Changed -Action $action | Out-Null
Register-ObjectEvent $watcher Created -Action $action | Out-Null
Register-ObjectEvent $watcher Deleted -Action $action | Out-Null
Register-ObjectEvent $watcher Renamed -Action $action | Out-Null

"azul-watch: watching $out" | Tee-Object -FilePath $log -Append | Write-Host
while ($true) {
    Start-Sleep -Seconds 2
    if ($pending) {
        $pending = $false
        Start-Sleep -Seconds 3 # let the compiler finish its burst
        Set-Location $root
        $stamp = Get-Date -Format "HH:mm:ss"
        $result = azul build --rojo --rojo-project default.project.json --no-warn 2>&1 | Select-Object -Last 3
        "[$stamp] $result" | Tee-Object -FilePath $log -Append | Write-Host
    }
}
