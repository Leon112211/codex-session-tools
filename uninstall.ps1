$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $HOME ".codex-session-tools"
$ModulePath = Join-Path $InstallDir "CodexSessionTools.psm1"

Write-Host ""
Write-Host "Uninstalling Codex Session Tools..." -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 1. Remove the module from the current session
# ============================================================

if (Get-Module CodexSessionTools -ErrorAction SilentlyContinue) {
    Remove-Module CodexSessionTools -Force
}

# Also remove old in-memory functions if they exist
Remove-Item Function:\Find-CodexSession -ErrorAction SilentlyContinue
Remove-Item Function:\Remove-CodexSessionHard -ErrorAction SilentlyContinue

# ============================================================
# 2. Clean PowerShell profile
# ============================================================

if (Test-Path $PROFILE) {

    Write-Host "[1/3] Cleaning PowerShell profile..."

    $ProfileText = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue

    if ($null -eq $ProfileText) {
        $ProfileText = ""
    }

    $OriginalText = $ProfileText

    # --------------------------------------------------------
    # Remove current module import entry
    # --------------------------------------------------------

    $ModuleImportPattern = '(?m)^\s*Import-Module\s+["'']?.*?CodexSessionTools\.psm1["'']?\s+-Force\s*$'
    $ProfileText = [regex]::Replace(
        $ProfileText,
        $ModuleImportPattern,
        ""
    )

    # Remove installer comment line
    $ProfileText = [regex]::Replace(
        $ProfileText,
        '(?m)^\s*# Codex Session Tools\s*$',
        ""
    )

    # --------------------------------------------------------
    # Remove legacy function blocks
    # --------------------------------------------------------

    function Remove-LegacyFunctionBlock {
        param(
            [string]$Text,
            [string]$FunctionName
        )

        $pattern = "(?ms)^\s*function\s+$([regex]::Escape($FunctionName))\s*\{"

        $match = [regex]::Match($Text, $pattern)

        if (-not $match.Success) {
            return $Text
        }

        $start = $match.Index
        $braceStart = $Text.IndexOf("{", $match.Index)

        if ($braceStart -lt 0) {
            return $Text
        }

        $depth = 0
        $end = -1

        for ($i = $braceStart; $i -lt $Text.Length; $i++) {

            $ch = $Text[$i]

            if ($ch -eq "{") {
                $depth++
            }
            elseif ($ch -eq "}") {
                $depth--

                if ($depth -eq 0) {
                    $end = $i
                    break
                }
            }
        }

        if ($end -lt 0) {
            throw "Failed to parse legacy function: $FunctionName"
        }

        $before = $Text.Substring(0, $start)
        $after  = $Text.Substring($end + 1)

        return ($before + $after)
    }

    $ProfileText = Remove-LegacyFunctionBlock `
        -Text $ProfileText `
        -FunctionName "Find-CodexSession"

    $ProfileText = Remove-LegacyFunctionBlock `
        -Text $ProfileText `
        -FunctionName "Remove-CodexSessionHard"

    # --------------------------------------------------------
    # Normalize excessive blank lines
    # --------------------------------------------------------

    $ProfileText = [regex]::Replace(
        $ProfileText,
        "(\r?\n){3,}",
        "`r`n`r`n"
    )

    $ProfileText = $ProfileText.Trim()

    if ($ProfileText.Length -gt 0) {
        $ProfileText += "`r`n"
    }

    if ($ProfileText -ne $OriginalText) {

        $BackupPath = "$PROFILE.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

        Copy-Item `
            -Path $PROFILE `
            -Destination $BackupPath `
            -Force

        Set-Content `
            -Path $PROFILE `
            -Value $ProfileText `
            -Encoding UTF8

        Write-Host "PowerShell profile cleaned."
        Write-Host "Backup:"
        Write-Host "  $BackupPath"
    }
    else {
        Write-Host "No Codex Session Tools entries found in profile."
    }
}
else {
    Write-Host "[1/3] PowerShell profile not found."
}

# ============================================================
# 3. Remove installed module files
# ============================================================

Write-Host ""
Write-Host "[2/3] Removing installed files..."

if (Test-Path $InstallDir) {

    Remove-Item `
        -Path $InstallDir `
        -Recurse `
        -Force

    Write-Host "Removed:"
    Write-Host "  $InstallDir"
}
else {
    Write-Host "Install directory already absent."
}

# ============================================================
# 4. Verify current session
# ============================================================

Write-Host ""
Write-Host "[3/3] Verifying cleanup..."

$FindExists = Get-Command `
    Find-CodexSession `
    -ErrorAction SilentlyContinue

$RemoveExists = Get-Command `
    Remove-CodexSessionHard `
    -ErrorAction SilentlyContinue

if ($FindExists -or $RemoveExists) {

    Write-Warning "One or more commands still exist in the current session."
    Write-Host "Close this PowerShell window and open a new one."
}
else {
    Write-Host "Current session commands removed."
}

Write-Host ""
Write-Host "Uninstallation completed." -ForegroundColor Green
Write-Host ""
Write-Host "Open a new PowerShell window, then verify with:"
Write-Host ""
Write-Host "  Get-Command Find-CodexSession -ErrorAction SilentlyContinue"
Write-Host "  Get-Command Remove-CodexSessionHard -ErrorAction SilentlyContinue"
Write-Host ""