# Codex Session Tools

Find and safely remove local Codex sessions on Windows, including stale Codex Desktop entries ("ghost sessions").

> [!WARNING]
> Deletion modifies local Codex state. Run delete commands from an independent PowerShell window after fully closing Codex and ChatGPT Desktop. If either app is still running, the command stops before changing data.

_This is an unofficial community project. It is not affiliated with or endorsed by OpenAI._

## Quick start

Install:

```powershell
irm https://raw.githubusercontent.com/Leon112211/codex-session-tools/main/install.ps1 | iex
```

List every detected session:

```powershell
Find-CodexSession
```

Find sessions by title:

```powershell
Find-CodexSession "hello"
```

Delete one session by UUID:

```powershell
Remove-CodexSessionHard -Uuid "01234567-89ab-cdef-0123-456789abcdef"
```

Find and delete multiple sessions:

```powershell
Find-CodexSession "old project" | Remove-CodexSessionsHard
```

The batch command shows the complete target list and asks for confirmation before deletion.

## Find sessions

### 1. List everything

```powershell
Find-CodexSession
```

### 2. Search by partial title

```powershell
Find-CodexSession "hello"
```

The default title search is case-insensitive and may return multiple sessions.

### 3. Match a title exactly

```powershell
Find-CodexSession "hello" -ExactTitle
```

Exact titles are still not guaranteed to be unique.

### 4. Find one UUID

```powershell
Find-CodexSession "01234567-89ab-cdef-0123-456789abcdef"
```

Each result includes its title, UUID, Core/Desktop presence, status, and working directory when available.

| Status | Meaning |
| --- | --- |
| `Core+Desktop` | Present in both Codex Core state and the Desktop catalog. |
| `CoreOnly` | Present only in Codex Core state. |
| `DesktopOnly (Ghost)` | Core state is gone, but a stale Desktop entry remains. |

## Delete one session

First find the session and verify its UUID:

```powershell
Find-CodexSession "hello"
```

Fully close Codex and ChatGPT Desktop, then run:

```powershell
Remove-CodexSessionHard -Uuid "01234567-89ab-cdef-0123-456789abcdef"
```

Deletion accepts a UUID, not a title. This prevents duplicate titles from identifying the wrong session.

## Delete multiple sessions

### 1. Review the matches

```powershell
Find-CodexSession "old project"
```

### 2. Preview the batch

After fully closing Codex and ChatGPT Desktop, run:

```powershell
Find-CodexSession "old project" | Remove-CodexSessionsHard -WhatIf
```

`-WhatIf` performs validation and preflight checks but does not delete anything.

### 3. Run the batch

```powershell
Find-CodexSession "old project" | Remove-CodexSessionsHard
```

Review the displayed table, then confirm the batch once when prompted.

> [!CAUTION]
> Every session produced by `Find-CodexSession` becomes a deletion target. Always inspect the matches or use `-WhatIf` before confirming.

### Select only ghost sessions

Preview all Desktop-only ghost sessions:

```powershell
Find-CodexSession |
    Where-Object Status -eq "DesktopOnly (Ghost)" |
    Remove-CodexSessionsHard -WhatIf
```

Remove them after reviewing the preview:

```powershell
Find-CodexSession |
    Where-Object Status -eq "DesktopOnly (Ghost)" |
    Remove-CodexSessionsHard
```

### Supply an explicit UUID list

```powershell
Remove-CodexSessionsHard -Uuid @(
    "01234567-89ab-cdef-0123-456789abcdef"
    "fedcba98-7654-3210-fedc-ba9876543210"
)
```

The batch command:

1. validates and de-duplicates every UUID;
2. verifies that every target exists before starting;
3. displays the complete deletion plan;
4. requests one confirmation;
5. deletes and verifies each session sequentially; and
6. stops after the first failure.

Completed deletions are not rolled back. Targets after a failure are reported as `NotRun`.

## Installation

### Inspect before installing (recommended)

```powershell
irm https://raw.githubusercontent.com/Leon112211/codex-session-tools/main/install.ps1 -OutFile install.ps1
notepad .\install.ps1
.\install.ps1
```

### One-line installation

Use this after you trust the source:

```powershell
irm https://raw.githubusercontent.com/Leon112211/codex-session-tools/main/install.ps1 | iex
```

The installer:

- checks for Python and the Codex CLI;
- installs `CodexSessionTools.psm1` under `$HOME\.codex-session-tools`;
- adds the module import to your PowerShell profile; and
- verifies that all three commands are available.

To use a local repository copy without installing it:

```powershell
Import-Module .\CodexSessionTools.psm1 -Force
```

## Requirements

- Windows
- PowerShell 5.1 or later
- Python 3 available as `python`
- Codex CLI available as `codex`
- Codex Desktop when Desktop catalog cleanup is needed

## Safety and backups

For every UUID, deletion:

1. refuses to run while Codex or ChatGPT processes are active;
2. uses `codex delete --force <UUID>` when Core state exists;
3. verifies Core cleanup before modifying Desktop metadata;
4. removes only matching global metadata and catalog rows; and
5. performs a final UUID verification.

Before changing matching Desktop data, timestamped backups are created where applicable:

```text
.codex-global-state.json.predelete-...
.codex-global-state.json.bak.predelete-...
codex-dev.backup-....db
```

Backups are stored alongside the original files under `$HOME\.codex`, or under the directory specified by `CODEX_HOME`.

The tool does **not intentionally** delete the entire Codex directory, unrelated sessions, authentication data, configuration, Core databases, or the complete Desktop catalog.

## Uninstallation

From a clone of this repository, run:

```powershell
.\uninstall.ps1
```

The uninstaller removes the installed module and its PowerShell profile entry. It backs up the profile before changing it.

## Troubleshooting

- **Codex/ChatGPT is still running:** fully exit the desktop app and its background processes, then retry from an independent PowerShell window.
- **`python` or `codex` was not found:** install the missing dependency and ensure it is available on `PATH`.
- **Commands are unavailable after installation:** open a new PowerShell window or import `$HOME\.codex-session-tools\CodexSessionTools.psm1` manually.
- **A batch reports `NotRun`:** an earlier target failed, so later targets were not touched.
- **Verification fails:** preserve the generated backups and review the reported paths; do not edit the databases blindly.

## Security

Never post session transcripts, authentication data, local databases, or unredacted Codex state in a public issue. See the [security policy](SECURITY.md) for reporting guidance.

Codex storage formats may change between releases, so future compatibility is not guaranteed. Use this project at your own risk.

## License

Licensed under the [MIT License](LICENSE).
