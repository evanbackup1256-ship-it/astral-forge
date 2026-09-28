# Saves your Roblox Open Cloud API key for tools/assetgen/upload.py.
#
#   powershell -ExecutionPolicy Bypass -File tools/assetgen/set-key.ps1
#
# The key is typed (or pasted) into a hidden prompt and stored in your Windows
# user environment as ROBLOX_API_KEY. It is never printed, logged or written
# into the project.

$secure = Read-Host "Paste your Open Cloud API key (input is hidden)" -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
}
if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Host "Nothing entered; no key saved."
    exit 1
}
[Environment]::SetEnvironmentVariable("ROBLOX_API_KEY", $key.Trim(), "User")
Write-Host "Saved. Now run:  python tools/assetgen/upload.py"
