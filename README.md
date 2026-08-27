# Codex Session Tools

PowerShell utilities for finding and precisely deleting individual local Codex sessions on Windows, including stale Codex Desktop entries ("ghost sessions").

> [!WARNING]
> This tool modifies local Codex state. Fully close Codex and ChatGPT Desktop before deleting a session, verify the target UUID carefully, and keep any important local data backed up. Codex storage formats may change between releases.

_This is an unofficial community project. It is not affiliated with or endorsed by OpenAI._

## Features

- Search sessions by title or UUID.
- List sessions found in Codex Core state, the Desktop catalog, or both.
- Identify stale Desktop-only entries.
- Delete exactly one session by UUID.
- Use the official Codex CLI deletion command when Core state exists.
- Back up Desktop state before changing matching records.
- Stop when the detected state is ambiguous or cannot be verified safely.

## Requirements

- Windows
- PowerShell 5.1 or later
- Python 3 available as `python`
- Codex CLI available as `codex`
- Codex Desktop, when Desktop session cleanup is needed

## Installation

### Inspect the installer first (recommended)

```powershell
irm https://raw.githubusercontent.com/Leon112211/codex-session-tools/main/install.ps1 -OutFile install.ps1
notepad .\install.ps1
.\install.ps1
```

### One-line installation

If you have reviewed the installer and trust the source:

```powershell
irm https://raw.githubusercontent.com/Leon112211/codex-session-tools/main/install.ps1 | iex
```

The installer downloads `CodexSessionTools.psm1` to `$HOME\.codex-session-tools` and adds an import line to your PowerShell profile. Open a new PowerShell window after installation if the commands are not immediately available.

## Usage

### Find sessions

Search by partial title:

```powershell
Find-CodexSession "hello"
```

Match a title exactly:

```powershell
Find-CodexSession "hello" -ExactTitle
```

Search by UUID:

```powershell
Find-CodexSession "01234567-89ab-cdef-0123-456789abcdef"
```

List all detected sessions:

```powershell
Find-CodexSession
```

Results include the session status, title, UUID, Core/Desktop presence, and working directory when available.

| Status | Meaning |
| --- | --- |
| `Core+Desktop` | The session exists in both Codex Core state and the Desktop catalog. |
| `CoreOnly` | The session exists only in Codex Core state. |
| `DesktopOnly (Ghost)` | Core state is gone, but the Desktop catalog still contains a stale entry. |

### Delete one session

1. Fully close Codex and ChatGPT Desktop.
2. Find the session and copy its UUID.
3. Run:

```powershell
Remove-CodexSessionHard -Uuid "01234567-89ab-cdef-0123-456789abcdef"
```

Session titles are not unique. Deletion therefore requires a valid UUID and does not accept a title.

## What deletion does

For the supplied UUID, `Remove-CodexSessionHard`:

1. Refuses to continue while a Codex or ChatGPT process is running.
2. Inspects session files, the session index, Core SQLite state, Desktop global metadata, and the Desktop thread catalog.
3. Runs `codex delete --force <UUID>` if the Core session exists.
4. Verifies that Core state is clean before modifying Desktop metadata.
5. Removes matching Desktop metadata and the matching catalog row.
6. Performs a final UUID verification and fails if any checked reference remains.

The tool does **not intentionally**:

- delete the entire `.codex` directory;
- delete every session;
- clear authentication data or Codex configuration;
- delete `state_*.sqlite` or `codex-dev.db`;
- clear the complete `local_thread_catalog` table; or
- modify unrelated sessions.

## Backups

Before changing matching Desktop data, the tool creates timestamped backups where applicable:

```text
.codex-global-state.json.predelete-...
.codex-global-state.json.bak.predelete-...
codex-dev.backup-....db
```

Backups are created alongside the original files under your Codex home directory (normally `$HOME\.codex`, or the directory specified by `CODEX_HOME`).

## Uninstallation

From a clone of this repository, run:

```powershell
.\uninstall.ps1
```

The uninstall script removes the installed module and its PowerShell profile entry. When it changes the profile, it creates a timestamped profile backup first.

## Troubleshooting

- **`python` or `codex` was not found:** ensure Python 3 and the Codex CLI are installed and available on `PATH`.
- **Codex/ChatGPT is still running:** fully exit the desktop app, including background processes, and retry.
- **Commands are unavailable after installation:** open a new PowerShell window or import `$HOME\.codex-session-tools\CodexSessionTools.psm1` manually.
- **Deletion aborts during verification:** do not edit the databases manually. Review the reported paths and preserve the generated backups before investigating further.

## Security and support

Do not post session transcripts, authentication data, local database files, or other sensitive Codex state in a public issue. See the [security policy](SECURITY.md) for reporting guidance.

Codex internal storage formats may change, so compatibility with future versions is not guaranteed. Use this project at your own risk.

## License

Licensed under the [MIT License](LICENSE).
