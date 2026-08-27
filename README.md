\# Codex Session Tools



PowerShell utilities for locating and precisely deleting local Codex sessions on Windows.



> \[!WARNING]

> This tool modifies local Codex state.

> Always fully close Codex / ChatGPT Desktop before running destructive operations.

> Codex internal storage formats may change between versions.



> \[!NOTE]

> This is an unofficial community project and is not affiliated with or endorsed by OpenAI.



\## Features



\- Search Codex sessions by title or UUID

\- Detect normal sessions and Desktop-only ghost sessions

\- Distinguish between:

&#x20; - `Core+Desktop`

&#x20; - `CoreOnly`

&#x20; - `DesktopOnly (Ghost)`

\- Precisely delete one session by UUID

\- Back up modified local state before cleanup

\- Abort when the detected state is ambiguous or unsafe



\## Requirements



\- Windows

\- PowerShell 5.1 or later

\- Python 3

\- Codex CLI

\- Codex Desktop, if Desktop session cleanup is required



\## Installation



\### One-line installation



```powershell

irm https://raw.githubusercontent.com/Leon112211/codex-session-tools/main/install.ps1 | iex



For users who prefer to inspect the installer first:



irm https://raw.githubusercontent.com/Leon112211/codex-session-tools/main/install.ps1 -OutFile install.ps1

notepad .\\install.ps1

.\\install.ps1

Commands

Find sessions



Search by title:



Find-CodexSession "hello"



Exact title match:



Find-CodexSession "hello" -ExactTitle



Search by UUID:



Find-CodexSession "01234567-89ab-cdef-0123-456789abcdef"



List all sessions:



Find-CodexSession

Delete a session



Fully close Codex / ChatGPT Desktop first, then run:



Remove-CodexSessionHard -Uuid "01234567-89ab-cdef-0123-456789abcdef"

Session status

Status	Meaning

Core+Desktop	Session exists in both Core state and Desktop catalog

CoreOnly	Session exists only in Core state

DesktopOnly (Ghost)	Core session is gone, but Desktop still contains a stale entry

Safety rule



Session titles are not unique.



Always use the UUID as the deletion identity.



What this tool does not intentionally delete



This tool does not intentionally:



delete the entire .codex directory

delete all sessions

clear authentication data

clear Codex configuration

delete state\_\*.sqlite

delete codex-dev.db

clear the entire local\_thread\_catalog

delete unrelated sessions

Backups



Before modifying Desktop state, the tool creates backups where applicable.



Examples:



.codex-global-state.json.predelete-...

.codex-global-state.json.bak.predelete-...

codex-dev.backup-....db

Uninstallation



An uninstall script is included:



.\\uninstall.ps1

Documentation



Detailed SOP documentation is available in the docs directory.



Disclaimer



Codex internal storage formats may change in future releases.



This project is unofficial and is not affiliated with or endorsed by OpenAI.



Use at your own risk.



License



MIT

