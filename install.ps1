$ErrorActionPreference = "Stop"

$RepoRawBase = "https://raw.githubusercontent.com/Leon112211/codex-session-tools/main"
$InstallDir  = Join-Path $HOME ".codex-session-tools"
$ModulePath  = Join-Path $InstallDir "CodexSessionTools.psm1"

Write-Host ""
Write-Host "Installing Codex Session Tools..." -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 1. Check basic requirements
# ============================================================

Write-Host "[1/5] Checking requirements..."

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python 3 was not found in PATH."
}

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    throw "Codex CLI was not found in PATH."
}

Write-Host "OK: Python"
Write-Host "OK: Codex CLI"

# ============================================================
# 2. Create install directory
# ============================================================

Write-Host ""
Write-Host "[2/5] Preparing installation directory..."

if (-not (Test-Path $InstallDir)) {
    New-Item `
        -ItemType Directory `
        -Path $InstallDir `
        -Force | Out-Null
}

Write-Host "Install directory:"
Write-Host "  $InstallDir"

# ============================================================
# 3. Download module
# ============================================================

Write-Host ""
Write-Host "[3/5] Downloading module..."

Invoke-WebRequest `
    -Uri "$RepoRawBase/CodexSessionTools.psm1" `
    -OutFile $ModulePath `
    -UseBasicParsing

if (-not (Test-Path $ModulePath)) {
    throw "Installation failed: module file was not downloaded."
}

Write-Host "Module downloaded:"
Write-Host "  $ModulePath"

# ============================================================
# 4. Configure PowerShell profile
# ============================================================

Write-Host ""
Write-Host "[4/5] Configuring PowerShell profile..."

$ProfileDir = Split-Path $PROFILE -Parent

if (-not (Test-Path $ProfileDir)) {
    New-Item `
        -ItemType Directory `
        -Path $ProfileDir `
        -Force | Out-Null
}

if (-not (Test-Path $PROFILE)) {
    New-Item `
        -ItemType File `
        -Path $PROFILE `
        -Force | Out-Null
}

$ImportLine = "Import-Module `"$ModulePath`" -Force"

$ProfileContent = ""

if (Test-Path $PROFILE) {
    $ProfileContent = Get-Content `
        $PROFILE `
        -Raw `
        -ErrorAction SilentlyContinue
}

if ($null -eq $ProfileContent) {
    $ProfileContent = ""
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

# ============================================================
# 5. Load and verify module
# ============================================================

Write-Host ""
Write-Host "[5/5] Loading and verifying module..."

Import-Module $ModulePath -Force

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
Write-Host "Examples:"
Write-Host '  Find-CodexSession "hello"'
Write-Host '  Remove-CodexSessionHard -Uuid "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"'
Write-Host ""
Write-Host "The module will be loaded automatically in future PowerShell sessions."
Write-Host ""