# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Does

A set of shell scripts for managing multiple Claude Code accounts on a single machine. It works by copying `~/.claude.json` and `~/.claude/` to a backup directory, then restoring them when switching accounts.

## Requirements

- bash 4.0+ or zsh (macOS ships bash 3.2 — `claude-next.sh` uses `mapfile`, so run `brew install bash` or use zsh)

## Installation

```bash
./init.sh
source ~/.zshrc   # or ~/.bashrc
```

## Commands

```bash
claude-switch save <name>   # Save current ~/.claude.json + ~/.claude/ as account
claude-switch <name>        # Switch to saved account (auto-saves current first)
claude-switch list          # List saved accounts
claude-switch status        # Show current account name
claude-switch remove <name> # Delete a saved account

claude-next                 # Round-robin to next account (alphabetical order)
claude-sync                 # Cross-sync ~/.claude/projects/ to all accounts
claude-config-sync          # Merge agents/skills/commands/memory/plugins; push settings files from current account to all
```

## Testing

Tests use bats-core (git submodule — no global install needed).

```bash
# First time only
git submodule update --init --recursive

# Run all tests
./run_tests.sh

# Run a single suite
./run_tests.sh switch        # claude-switch.sh
./run_tests.sh next          # claude-next.sh
./run_tests.sh sync          # claude-sync.sh
./run_tests.sh init          # init.sh
./run_tests.sh config-sync   # claude-config-sync.sh
```

Each test runs in a sandboxed `$HOME` (a temp dir created in `setup()` and deleted in `teardown()` in `tests/setup.bash`). Real `~/.claude.json` and `~/.claude-accounts/` are never touched. Helper functions `fixture_account` and `fixture_current` pre-populate the sandbox without going through the switch command.

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

### Locking

All scripts use the same mkdir-based lock (`~/.claude-accounts/.lock.d/`). Since `claude-next.sh` calls `claude-switch.sh` as a subprocess, it sets `CLAUDE_LOCKED=1` in the environment. `claude-switch.sh` skips acquiring the lock when this variable is set — but only after verifying `$PPID` matches the PID in the lock file, preventing external processes from bypassing the lock.

### `claude-sync.sh` vs `claude-config-sync.sh`

| Script | What it syncs | Merge strategy |
|--------|--------------|----------------|
| `claude-sync.sh` | `~/.claude/projects/` (session history) | `cp -rPn` — existing files win; current account first |
| `claude-config-sync.sh` | `agents/`, `skills/`, `commands/`, `memory/`, `plugins/` (merged); `settings.json`, `settings.local.json`, `CLAUDE.md` (current account overwrites) | Directories merged across all; single files pushed from current |

### Key constraints

- Account names must match `[a-zA-Z0-9_-]+` — validated in `validate_name()` in `claude-switch.sh`.
- The lock is process-scoped: if the PID in `.lock.d/pid` is no longer alive, the stale lock is recovered by overwriting the pid file in-place (avoids TOCTOU with `rm -rf` + `mkdir`).
- Account switches are atomic: new data is copied to a `.tmp.$$` path first, then `mv` installs it — a killed script leaves either old or new state, never nothing.
- Symlink guards: every `cp`/`rm -rf` on account paths checks `[ ! -L ]` first; copies use `cp -rP` to preserve rather than follow symlinks.
- All scripts set `umask 077` on startup so every file created is private before explicit `chmod` is applied.
