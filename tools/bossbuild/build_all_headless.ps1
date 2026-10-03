# Builds every boss (model, rig, bake, clips, GLB, rig JSON) with Blender running headless, two at a
# time, at below-normal priority and a few threads each so it stays out of the way of the machine.
#
#   powershell -File tools/bossbuild/build_all_headless.ps1            # all seven
#   powershell -File tools/bossbuild/build_all_headless.ps1 Knight Seraph
#
# Logs go to %TEMP%\boss_build_<Kind>.log. Output goes to assets/generated/bosses/.

param([string[]]$Kinds = @("Knight", "Seraph", "Warden", "Choir", "Regent", "Rime", "Astraeon"))

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
Set-Location $root
Remove-Item Env:FAST -ErrorAction SilentlyContinue
Remove-Item Env:CLIP -ErrorAction SilentlyContinue
Remove-Item Env:TAG -ErrorAction SilentlyContinue
$env:POSE = "idle"
$env:VIEWS = "front,three,back34"

function Start-Build($kind) {
    $env:BOSS = $kind
    $log = Join-Path $env:TEMP "boss_build_$kind.log"
    $p = Start-Process -FilePath $blender -ArgumentList @("-b", "-t", "4", "--python", "tools/bossbuild/build_boss.py") -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -WindowStyle Hidden
    try { $p.PriorityClass = "BelowNormal" } catch {}
    return $p
}

for ($i = 0; $i -lt $Kinds.Count; $i += 2) {
    $batch = @()
    foreach ($kind in $Kinds[$i..([Math]::Min($i + 1, $Kinds.Count - 1))]) {
        Write-Output "starting $kind"
        $batch += Start-Build $kind
    }
    $batch | Wait-Process
    foreach ($kind in $Kinds[$i..([Math]::Min($i + 1, $Kinds.Count - 1))]) {
        $line = Select-String -Path (Join-Path $env:TEMP "boss_build_$kind.log") -Pattern "^$kind\:" | Select-Object -Last 1
        Write-Output ("{0}: {1}" -f $kind, $(if ($line) { $line.Line.Substring(0, [Math]::Min(100, $line.Line.Length)) } else { "NO RESULT LINE (see the log)" }))
    }
}
Write-Output "all builds finished"
