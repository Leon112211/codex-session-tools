$ErrorActionPreference = "Stop"

$RepoRawBase = "https://raw.githubusercontent.com/Leon112211/codex-session-tools/main"
$InstallDir  = Join-Path $HOME ".codex-session-tools"
$ModulePath  = Join-Path $InstallDir "CodexSessionTools.psm1"

Write-Host ""
Write-Host "Installing Codex Session Tools..." -ForegroundColor Cyan
Write-Host ""

# 1. Create install directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# 2. Download module
Write-Host "[1/4] Downloading module..."

Invoke-WebRequest `
    -Uri "$RepoRawBase/CodexSessionTools.psm1" `
    -OutFile $ModulePath `
    -UseBasicParsing

if (-not (Test-Path $ModulePath)) {
    throw "Installation failed: module file was not downloaded."
}

Write-Host "Module installed to:"
Write-Host "  $ModulePath"

# 3. Ensure PowerShell profile exists
Write-Host ""
Write-Host "[2/4] Configuring PowerShell profile..."

$ProfileDir = Split-Path $PROFILE -Parent

if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$ImportLine = "Import-Module `"$ModulePath`" -Force"

$ProfileContent = ""
if (Test-Path $PROFILE) {
    $ProfileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
}

if ($ProfileContent -notmatch [regex]::Escape($ImportLine)) {

    Add-Content $PROFILE ""
    Add-Content $PROFILE "# Codex Session Tools"
    Add-Content $PROFILE $ImportLine

    Write-Host "PowerShell profile updated."
}
else {
    Write-Host "PowerShell profile already configured."
}

# 4. Load module now
Write-Host ""
Write-Host "[3/4] Loading module..."

Import-Module $ModulePath -Force

# 5. Verify commands
Write-Host ""
Write-Host "[4/4] Verifying installation..."

$RequiredCommands = @(
    "Find-CodexSession",
    "Remove-CodexSessionHard"
)

foreach ($Command in $RequiredCommands) {

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Installation failed: $Command is unavailable."
    }

    Write-Host "OK: $Command"
}

Write-Host ""
Write-Host "Installation successful." -ForegroundColor Green
Write-Host ""
Write-Host "Available commands:"
Write-Host "  Find-CodexSession"
Write-Host "  Remove-CodexSessionHard"
Write-Host ""
Write-Host "Example:"
Write-Host '  Find-CodexSession "hello"'
Write-Host '  Remove-CodexSessionHard -Uuid "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"'
Write-Host ""