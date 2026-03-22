# Claude Code Multi-Account Switcher

Quickly switch between multiple Claude Code accounts.

## Requirements

- bash 4.0+ or zsh (macOS ships bash 3.2 — use `brew install bash` for `mapfile` support, or use zsh)

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

# Run all tests
./run_tests.sh

# Run a single suite
./run_tests.sh switch   # claude-switch.sh
./run_tests.sh next     # claude-next.sh
./run_tests.sh sync     # claude-sync.sh
./run_tests.sh init     # init.sh
./run_tests.sh config-sync  # claude-config-sync.sh
```

Tests run in a sandboxed `$HOME` (a temp directory per test) — your real `~/.claude.json` and `~/.claude-accounts/` are never touched.

## Security

All account data is stored at `~/.claude-accounts/` with restricted permissions (`700` on the directory, `600` on token files). A `.gitignore` is automatically created inside to prevent accidental commits.

| Protection | Detail |
|------------|--------|
| **umask 077** | All scripts set `umask 077` on startup so every file created during a copy or temp operation is private before `chmod` is applied — no brief world-readable window on token files. |
| **Atomic account switch** | `~/.claude` and `<account>-dir` are never absent during a switch. New data is fully copied to a temp path first, then the old directory is removed, then `mv` installs the new one. A killed script leaves either the old or the new state intact, never nothing. |
| **Symlink guards** | Before every `cp` or `rm -rf` on account paths, the script verifies the target is not a symlink (`[ ! -L ]`). All copies use `cp -rP` to preserve symlinks rather than follow them. |
| **Lock ownership check** | `CLAUDE_LOCKED=1` (used by `claude-next.sh` to avoid deadlock) is only honoured when `$PPID` matches the PID written in the lock file. Arbitrary external processes setting this variable are rejected with an error. |
| **Stale lock recovery** | A stale lock (dead PID) is recovered by overwriting the pid file in-place rather than `rm -rf` + `mkdir`, closing the TOCTOU window where two racing processes could both acquire the lock. |
| **Safe temp dirs** | Sync temp directories are created inside `~/.claude-accounts/` (already `chmod 700`) instead of world-listable `/tmp`, and are registered in the `EXIT` trap so they are always cleaned up even on SIGTERM/SIGINT. |
| **Name validation** | Account names are validated to `[a-zA-Z0-9_-]` — no path traversal via state files. |
| **RC file safety** | `init.sh` rejects install paths containing control characters before writing to the RC file, and uses `grep -qF "alias NAME="` for precise duplicate detection. |
| **Token isolation** | Token files (`*.json`) are never touched by `claude-sync` or `claude-config-sync` — only conversation history and config directories are shared. |
