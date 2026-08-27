$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $HOME ".codex-session-tools"
$ModulePath = Join-Path $InstallDir "CodexSessionTools.psm1"

Write-Host ""
Write-Host "Uninstalling Codex Session Tools..." -ForegroundColor Cyan
Write-Host ""

# 1. Remove the module from the current PowerShell session
if (Get-Module CodexSessionTools -ErrorAction SilentlyContinue) {
    Remove-Module CodexSessionTools -Force
}

# 2. Remove the profile import line
if (Test-Path $PROFILE) {

    $ProfileLines = Get-Content $PROFILE

    $FilteredLines = $ProfileLines | Where-Object {
        $_ -notmatch [regex]::Escape($ModulePath) -and
        $_ -ne "# Codex Session Tools"
    }

    Set-Content `
        -Path $PROFILE `
        -Value $FilteredLines `
        -Encoding UTF8
}

# 3. Remove installed files
if (Test-Path $InstallDir) {
    Remove-Item `
        -Path $InstallDir `
        -Recurse `
        -Force
}

Write-Host ""
Write-Host "Uninstallation successful." -ForegroundColor Green
Write-Host ""
Write-Host "Removed:"
Write-Host "  $InstallDir"
Write-Host "  PowerShell profile import entry"
Write-Host ""
Write-Host "Open a new PowerShell window to complete the cleanup."
Write-Host ""