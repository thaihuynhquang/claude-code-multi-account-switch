# Security Audit Report & Fix Plan

**Date:** 2026-03-22
**Scope:** All shell scripts in claude-code-multi-account-switch

---

## Audit Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 3 |
| Medium | 5 |
| Low | 7 |
| Info | 1 |
| **Total** | **16** |

---

## Findings

### HIGH

#### H1. Non-Atomic Account Switch — Data Loss on Crash
**File:** `claude-switch.sh:42-56, 67-69`

`rm -rf ~/.claude; cp -r backup-dir ~/.claude` means if the script is killed between the `rm` and `cp` (SIGKILL, disk full, power loss), `~/.claude` is permanently deleted and the new account's files haven't been restored.

Same pattern in the `save` command (line 67-69) and auto-save (line 47).

**Fix:** Copy new data to a temp location inside `$BACKUP_DIR`, then `mv` (atomic rename on same filesystem) into place. Only delete old data after the new data is in place.

---

#### H2. `CLAUDE_LOCKED` Environment Variable Bypass
**File:** `claude-switch.sh:13`

`if [ -z "$CLAUDE_LOCKED" ]` skips all locking. Designed for `claude-next.sh` to avoid deadlock, but any external process can set `CLAUDE_LOCKED=1` to run unserialized operations on account files.

**Fix:** Verify `$PPID` matches the PID in the lock file. Only trust `CLAUDE_LOCKED` when the parent process is actually the lock holder.

---

#### H3. Symlink Attack on BACKUP_DIR Contents
**File:** `claude-switch.sh:45-54, 67-69`

If a symlink exists at `$BACKUP_DIR/<name>.json` or `$BACKUP_DIR/<name>-dir`, `cp` follows it, potentially overwriting arbitrary files or reading from attacker-controlled locations. `rm -rf` on a symlinked `-dir` could delete unintended targets.

**Mitigating factor:** `$BACKUP_DIR` is `chmod 700`, so only the owning user can create symlinks.

**Fix:** Add `[ ! -L "$path" ]` guards before `cp`/`rm -rf`. Use `cp -rP` to preserve symlinks instead of following them.

---

### MEDIUM

#### M1. TOCTOU Race in Stale Lock Recovery
**Files:** `claude-switch.sh:16-21`, `claude-sync.sh:10-16`, `claude-next.sh:9-15`, `claude-config-sync.sh:11-17`

When a stale lock is detected (dead PID), `rm -rf "$LOCK_DIR"; mkdir "$LOCK_DIR"` is not atomic. Two concurrent instances can both detect the stale lock, both remove it, and both create their own lock.

**Fix:** Overwrite the `pid` file inside the existing lock directory instead of removing and recreating it.

---

#### M2. `cp -r` Follows Symlinks in Sync Scripts
**Files:** `claude-sync.sh:27,31,38,44`, `claude-config-sync.sh:35,39,45,51`

`cp -r` follows symlinks. A symlink inside a saved account's `projects/` could exfiltrate data from arbitrary locations into all other accounts during sync.

**Fix:** Use `cp -rP` (preserve symlinks) instead of `cp -r`.

---

#### M3. Temp Directory Not Cleaned on Signals
**Files:** `claude-sync.sh:23,49`, `claude-config-sync.sh:31,55`

`mktemp -d` directories containing session data are only cleaned at the end of the function. If killed by SIGTERM/SIGINT, sensitive data remains in `/tmp`.

**Fix:** Register temp dirs in the EXIT trap handler.

---

#### M4. Token File Briefly World-Readable (Umask Race)
**Files:** `claude-switch.sh:52-53, 67-68`

```bash
cp "$BACKUP_DIR/$account.json" "$CLAUDE_CONFIG"   # created with default umask (e.g., 644)
chmod 600 "$CLAUDE_CONFIG"                          # fixed, but window exists
```

**Fix:** Add `umask 077` at the top of all scripts.

---

#### M5. `rm -rf ~/.claude` Without Symlink Check
**File:** `claude-switch.sh:47,54,69`

If `~/.claude` is a symlink, `rm -rf` behavior varies by platform. Adding `[ ! -L "$CLAUDE_DIR" ]` before deletion is defensive.

**Fix:** Add symlink guard before `rm -rf` on `$CLAUDE_DIR`.

---

### LOW

#### L1. Glob Pattern `*-dir`/`*.json` Matches Unintended Files
**Files:** `claude-sync.sh:30,41`, `claude-config-sync.sh:38,48,62,70,87`, `claude-next.sh:22`

Any file matching these patterns in `BACKUP_DIR` is treated as an account, even if not created by these scripts.

**Mitigating factor:** `BACKUP_DIR` is `chmod 700`.

---

#### L2. `init.sh` Newline in Path → RC File Injection
**File:** `init.sh:18-22`

A directory name containing `\n` could inject arbitrary lines into `~/.zshrc`/`~/.bashrc`.

**Fix:** Validate `$DIR` doesn't contain newlines or control characters before writing.

---

#### L3. `init.sh` grep Pattern Too Broad
**File:** `init.sh:19-22`

`grep -q "claude-switch="` matches any line containing that string, not just aliases.

**Fix:** Use `grep -qF "alias claude-switch="`.

---

#### L4. Glob Expansion in `claude-next.sh` Sort
**File:** `claude-next.sh:30`

```bash
IFS=$'\n' accounts=($(sort <<<"${accounts[*]}")); unset IFS
```

Unquoted command substitution could glob-expand if account names contained `*` or `?`. Prevented by name validation, but `claude-next.sh` doesn't validate names read from disk.

**Fix:** Use `mapfile -t accounts < <(printf '%s\n' "${accounts[@]}" | sort)`.

---

#### L5. Unquoted `$CONFIG_DIRS`/`$CONFIG_FILES`
**File:** `claude-config-sync.sh:79,83`

Word-split iteration over space-separated strings. Safe today (hardcoded values), but fragile.

**Fix:** Use bash arrays.

---

#### L6. Temp Dirs in World-Listable `/tmp`
**Files:** `claude-sync.sh:23`, `claude-config-sync.sh:31`

Directory names in `/tmp` reveal tool usage. Contents are protected by `chmod 700` but directory existence is visible.

**Fix:** Create temp dirs inside `$BACKUP_DIR` (already `chmod 700`).

---

#### L7. Unquoted `$$` in PID File Write
**Files:** All scripts, PID write lines

`echo $$ > "$LOCK_DIR/pid"` — `$$` is always numeric, so no actual risk. Cosmetic.

---

### INFO

#### I1. `$0` in Error Messages
**Files:** `claude-switch.sh:58,64`, `claude-sync.sh:58`, `claude-config-sync.sh:100`

Full script path leaked in error messages. Use `basename "$0"` for cleaner output.

---

## Fix Plan

### Commit 1: `fix: add umask 077 to all scripts to prevent token file permission race`

Add `umask 077` after `#!/bin/bash` in all 4 scripts. Smallest, safest change. Fixes M4.

### Commit 2: `fix: atomic account switch, symlink guards, and safe temp dirs`

| Change | Files | Fixes |
|--------|-------|-------|
| Copy-to-temp-then-`mv` for account switch/save | `claude-switch.sh` | H1, M5 |
| `[ ! -L ]` symlink guards before `rm -rf`/`cp` | `claude-switch.sh` | H3 |
| `cp -rP` instead of `cp -r` | `claude-sync.sh`, `claude-config-sync.sh`, `claude-switch.sh` | M2 |
| Temp dirs inside `$BACKUP_DIR` + trap cleanup | `claude-sync.sh`, `claude-config-sync.sh` | M3, L6 |

### Commit 3: `fix: harden locking, env bypass, init.sh patterns, and array quoting`

| Change | Files | Fixes |
|--------|-------|-------|
| Overwrite pid file instead of rm+mkdir for stale locks | All 4 scripts | M1 |
| PPID verification for `CLAUDE_LOCKED` | `claude-switch.sh` | H2 |
| `mapfile` instead of unquoted sort | `claude-next.sh` | L4 |
| Bash arrays for `CONFIG_DIRS`/`CONFIG_FILES` | `claude-config-sync.sh` | L5 |
| Validate DIR for control chars | `init.sh` | L2 |
| `grep -qF "alias ..."` | `init.sh` | L3 |
| Update tests for CLAUDE_LOCKED behavior change | `tests/switch.bats` | — |

---

## Files to Modify

| File | Commits |
|------|---------|
| `claude-switch.sh` | 1, 2, 3 |
| `claude-sync.sh` | 1, 2, 3 |
| `claude-next.sh` | 1, 3 |
| `claude-config-sync.sh` | 1, 2, 3 |
| `init.sh` | 3 |
| `tests/switch.bats` | 3 |

## Verification

1. `./run_tests.sh` — all tests pass after each commit
2. Manual: `claude-switch save test1`, `claude-switch test1`, `claude-next`
3. `stat -f '%Lp' ~/.claude.json` shows `600` after switch
4. `CLAUDE_LOCKED=1 ./claude-switch.sh list` fails with "not the lock holder"
5. Kill switch mid-operation — `~/.claude` is either fully old or fully new, never missing
