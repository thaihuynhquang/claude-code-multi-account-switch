# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Does

A set of shell scripts for managing multiple Claude Code accounts on a single machine. It works by copying `~/.claude.json` and `~/.claude/` to a backup directory, then restoring them when switching accounts.

## Installation

```bash
./init.sh
source ~/.zshrc   # or ~/.bashrc
```

This adds aliases to your shell RC file pointing to the scripts in this directory.

## Commands

```bash
claude-switch save <name>   # Save current ~/.claude.json + ~/.claude/ as account
claude-switch <name>        # Switch to saved account (auto-saves current first)
claude-switch list          # List saved accounts
claude-switch status        # Show current account name
claude-switch remove <name> # Delete a saved account

claude-next                 # Round-robin to next account (alphabetical order)
claude-sync                 # Cross-sync ~/.claude/projects/ to all accounts
```

## Architecture

### Storage layout (`~/.claude-accounts/`)

| Path | Purpose |
|------|---------|
| `<name>.json` | Copy of `~/.claude.json` (auth tokens) |
| `<name>-dir/` | Copy of `~/.claude/` (config + session history) |
| `.current` | Plain-text file with the active account name |
| `.lock.d/` | mkdir-based mutex directory (contains `pid` file) |
| `.gitignore` | Contains `*` to prevent accidental token commits |

Permissions: `700` on the directory, `600` on `.json` token files.

### Locking (`claude-switch.sh`, `claude-sync.sh`, `claude-next.sh`)

All three scripts use the same mkdir-based lock (`~/.claude-accounts/.lock.d/`). Since `claude-next.sh` calls `claude-switch.sh` as a subprocess, it sets `CLAUDE_LOCKED=1` in the environment. `claude-switch.sh` skips acquiring the lock when this variable is set, avoiding a deadlock.

### `claude-sync.sh`

Collects `~/.claude/projects/` from the active account and every `<name>-dir/projects/` into a temp directory (using `cp -rn` so existing files win), then distributes the merged result back to all locations. Only conversation history is synced — token files are never touched.

## Key Constraints

- Account names must match `[a-zA-Z0-9_-]+` — validated in `validate_name()` in `claude-switch.sh`.
- The lock is process-scoped: if the PID in `.lock.d/pid` is no longer alive, the stale lock is cleared and re-acquired automatically.
