# Security Policy

## Reporting a security issue

If you discover a security issue in this project, do not include sensitive local Codex data in a public GitHub issue.

Sensitive data may include:

- `.codex-global-state.json`
- `.codex-global-state.json.bak`
- `state_*.sqlite`
- `codex-dev.db`
- session transcripts and logs
- authentication data
- local project paths
- real session UUIDs

Share only the minimum information needed to reproduce the problem. Redact UUIDs, user names, project paths, tokens, credentials, and transcript content from logs or screenshots before sharing them.

For a suspected vulnerability that should not be public, use GitHub's private vulnerability reporting feature if it is enabled for this repository. Otherwise, contact the repository owner privately through an available GitHub profile contact method.

## Local data warning

Codex Session Tools operates on local Codex state. Before using a destructive command:

- back up important local data;
- fully close Codex and ChatGPT Desktop; and
- verify the target UUID carefully.

The deletion command is designed to operate on one explicitly supplied UUID and to stop when expected data structures are ambiguous or cannot be verified safely.

## Supported environment

This project is primarily intended for Windows with PowerShell 5.1 or later, Python 3, the Codex CLI, and Codex Desktop.

Internal Codex storage formats may change between releases, so compatibility is not guaranteed across all versions.

## Disclosure

This is an unofficial community project. It is not affiliated with or endorsed by OpenAI.
