# Keeps this clone on the newest pushed commit of a branch while Argon serves it,
# so cloud-agent pushes reach Roblox Studio within a few seconds.
#
# Usage (from the repo folder, PowerShell):
#   .\scripts\sync-argon.ps1                 # follows origin/master
#   .\scripts\sync-argon.ps1 -Branch my-branch
#
# It runs `argon serve default.project.json` in the background and, every
# -IntervalSeconds, fetches the branch and hard-resets to it when it moved.
# Argon sees the file changes on disk and pushes them into Studio.
# WARNING: reset --hard discards local uncommitted edits (including Studio edits
# written back by Argon). Source of truth is git, as in the README.
param(
	[string]$Branch = "master",
	[int]$IntervalSeconds = 5
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

git fetch origin $Branch
git checkout -B $Branch "origin/$Branch"

$argon = Start-Process -FilePath "argon" -ArgumentList "serve", "default.project.json" -PassThru -NoNewWindow
Write-Host "Argon serving (pid $($argon.Id)); following origin/$Branch every ${IntervalSeconds}s. Ctrl+C to stop."

try {
	while (-not $argon.HasExited) {
		Start-Sleep -Seconds $IntervalSeconds
		git fetch origin $Branch 2>$null
		if ($LASTEXITCODE -ne 0) { continue }
		$local = git rev-parse HEAD
		$remote = git rev-parse "origin/$Branch"
		if ($local -ne $remote) {
			git reset --hard "origin/$Branch" | Out-Null
			Write-Host ("[{0}] synced to {1}" -f (Get-Date -Format T), $remote.Substring(0, 7))
		}
	}
} finally {
	if (-not $argon.HasExited) { Stop-Process -Id $argon.Id }
}
