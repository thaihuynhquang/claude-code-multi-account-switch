# Claude Code Multi-Account Switcher

Quickly switch between multiple Claude Code accounts.

## Requirements

- bash or zsh
- Python 3 (standard library only, no `pip install` needed)

## Installation

```bash
./init.sh
source ~/.zshrc   # or ~/.bashrc for bash users
```

`init.sh` detects your shell, writes aliases to the correct RC file, and safely escapes the install path to prevent shell injection.

Aliases created:
- `claude-switch` → `claude-switch.sh`
- `claude-sync` → `claude-sync.sh`
- `claude-next` → `claude-next.sh`
- `claude-usage` → `python3 claude-usage.py`
- `claude-config-sync` → `claude-config-sync.sh`

## Usage

### Save an account

```bash
claude login                    # Login with Claude
claude-switch save work         # Save current session as "work"
```

Account names may only contain letters, numbers, `_`, and `-`.

### Switch account

```bash
claude-switch work
claude-switch personal
```

The previous account is auto-saved before switching.

### Other commands

```bash
claude-switch list      # List all saved accounts
```
<img width="784" height="114" alt="Screenshot from 2025-12-22 22-51-28" src="https://github.com/user-attachments/assets/b4c71d33-23ae-4152-a529-b6d1c40e60de" />

```bash
claude-switch status    # Show current account
```
<img width="853" height="45" alt="Screenshot from 2025-12-22 22-51-04" src="https://github.com/user-attachments/assets/01e8f373-e175-4584-8992-935239903f34" />

```bash
claude-switch remove work  # Remove a saved account
```

```bash
claude-next             # Switch to next account (round-robin)
```
<img width="727" height="63" alt="Screenshot from 2025-12-22 22-50-34" src="https://github.com/user-attachments/assets/8cbcbe21-c347-4adc-aa66-cfbf6a5563b3" />

```bash
claude-usage            # Show usage for all accounts
```
<img width="880" height="306" alt="Screenshot from 2025-12-22 22-51-49" src="https://github.com/user-attachments/assets/d29e01ba-18d5-4b49-aa94-2da9d47ed362" />

## Sync Config Between Accounts

Share skills, agents, commands, settings, memory, and plugins across all accounts.

```bash
claude-config-sync    # Sync all config from current account to all others
```

What gets synced:

| Category | Path |
|----------|------|
| Custom agents | `~/.claude/agents/` |
| Custom skills | `~/.claude/skills/` |
| Custom commands | `~/.claude/commands/` |
| Global memory | `~/.claude/memory/` |
| Plugins | `~/.claude/plugins/` |
| Settings | `~/.claude/settings.json` |
| Local settings | `~/.claude/settings.local.json` |
| Global instructions | `~/.claude/CLAUDE.md` |

For directories, files are **merged** across all accounts (no agent or skill is lost). For single files, the **current account's version** is distributed to all others.

> Note: session tokens are never touched by this command.

## Sync Sessions Between Accounts

Share conversation history between all accounts so `claude --resume` works on any account.

```bash
claude-sync    # Cross-sync all sessions between accounts
```

> Note: sync shares conversation history only — login tokens are never shared between accounts.

### Workflow

```bash
# Work on account1, create new session
claude-switch account1
claude

# Sync sessions to all accounts
claude-sync

# Switch to account2, resume same session
claude-switch account2
claude --resume
```

## Testing

The test suite uses [bats-core](https://github.com/bats-core/bats-core) (included as a git submodule — no global install needed).

```bash
# First time: initialize submodules
git submodule update --init --recursive

# Run all tests (60 tests across all scripts)
./run_tests.sh

# Run a single suite
./run_tests.sh switch   # claude-switch.sh
./run_tests.sh next     # claude-next.sh
./run_tests.sh sync     # claude-sync.sh
./run_tests.sh init     # init.sh
./run_tests.sh usage         # claude-usage.py (parse_usage only, no real claude binary needed)
./run_tests.sh config-sync  # claude-config-sync.sh
```

Tests run in a sandboxed `$HOME` (a temp directory per test) — your real `~/.claude.json` and `~/.claude-accounts/` are never touched.

## Storage

All account data is stored at `~/.claude-accounts/` with restricted permissions (`700` on the directory, `600` on token files). A `.gitignore` is automatically created inside to prevent accidental commits.

## Security

- Account names are validated to `[a-zA-Z0-9_-]` — no path traversal via state files
- Install path is shell-escaped with `printf %q` before writing to RC files
- Concurrent script executions are serialized with a `mkdir`-based lock to prevent config corruption (macOS-compatible — no `flock` required)
- Token files are never synced or shared between accounts
