\# Security Policy



\## Reporting a Security Issue



If you discover a security issue in this project, please do not include sensitive local Codex data in a public GitHub issue.



Sensitive data may include:



\- `.codex-global-state.json`

\- `.codex-global-state.json.bak`

\- `state\_\*.sqlite`

\- `codex-dev.db`

\- session transcripts

\- logs

\- authentication data

\- local project paths

\- real session UUIDs



When reporting an issue, please provide only the minimum information required to reproduce the problem.



\## Local Data Warning



Codex Session Tools operates on local Codex state.



Before using destructive commands:



\- back up important local data

\- fully close Codex / ChatGPT Desktop

\- verify the target UUID carefully



The tool is designed to operate on one explicitly supplied UUID and to abort when expected structures are ambiguous or unsafe.



\## Supported Environment



This project is primarily intended for:



\- Windows

\- PowerShell 5.1 or later

\- Python 3

\- Codex CLI

\- Codex Desktop



Internal Codex storage formats may change between releases, so compatibility is not guaranteed across all versions.



\## Disclosure



This is an unofficial community project and is not affiliated with or endorsed by OpenAI.

