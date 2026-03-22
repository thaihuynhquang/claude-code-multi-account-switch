#!/bin/bash

# Claude Config Sync - Cross-sync skills, agents, commands, settings, memory,
# and plugins across ALL saved accounts.

BACKUP_DIR="$HOME/.claude-accounts"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$BACKUP_DIR"
LOCK_DIR="$BACKUP_DIR/.lock.d"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    old_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        echo "[ERROR] Another instance is running (PID $old_pid)"; exit 1
    fi
    rm -rf "$LOCK_DIR"
    mkdir "$LOCK_DIR" || { echo "[ERROR] Cannot acquire lock"; exit 1; }
fi
echo $$ > "$LOCK_DIR/pid"
trap 'rm -rf "$LOCK_DIR"' EXIT

# Directories to merge across all accounts (current account wins conflicts)
CONFIG_DIRS="agents skills commands memory plugins"

# Single files to push from the current account to all saved accounts
CONFIG_FILES="settings.json settings.local.json CLAUDE.md"

sync_dir() {
    local name="$1"   # e.g. "agents"
    local tmp
    tmp=$(mktemp -d)
    chmod 700 "$tmp"

    # Current account first (wins conflicts via cp -rn below)
    [ -d "$CLAUDE_DIR/$name" ] && cp -r "$CLAUDE_DIR/$name/." "$tmp/" 2>/dev/null

    # Saved accounts (no overwrite)
    for account_dir in "$BACKUP_DIR"/*-dir; do
        [ -d "$account_dir/$name" ] && cp -rn "$account_dir/$name/." "$tmp/" 2>/dev/null
    done

    if [ -n "$(ls -A "$tmp" 2>/dev/null)" ]; then
        # To current account
        mkdir -p "$CLAUDE_DIR/$name"
        cp -r "$tmp/." "$CLAUDE_DIR/$name/"

        # To all saved accounts
        for account_dir in "$BACKUP_DIR"/*-dir; do
            [ -d "$account_dir" ] || continue
            mkdir -p "$account_dir/$name"
            cp -r "$tmp/." "$account_dir/$name/"
        done
    fi

    rm -rf "$tmp"
}

sync_file() {
    local file="$1"   # e.g. "settings.json"
    [ -f "$CLAUDE_DIR/$file" ] || return 0

    for account_dir in "$BACKUP_DIR"/*-dir; do
        [ -d "$account_dir" ] || continue
        cp "$CLAUDE_DIR/$file" "$account_dir/$file"
    done
}

sync_config() {
    local has_accounts=0
    for account_dir in "$BACKUP_DIR"/*-dir; do
        [ -d "$account_dir" ] && has_accounts=1 && break
    done

    if [ "$has_accounts" -eq 0 ]; then
        echo "[ERROR] No saved accounts found. Save an account first with: claude-switch save <name>"
        exit 1
    fi

    for name in $CONFIG_DIRS; do
        sync_dir "$name"
    done

    for file in $CONFIG_FILES; do
        sync_file "$file"
    done

    for account_dir in "$BACKUP_DIR"/*-dir; do
        [ -d "$account_dir" ] || continue
        echo "[OK] Synced config: $(basename "$account_dir" -dir)"
    done

    echo "[OK] Config sync complete!"
}

case "$1" in
    ""|sync)
        sync_config
        ;;
    *)
        echo "Usage: $0 [sync]"
        echo "Cross-sync agents, skills, commands, settings, memory, and plugins across all accounts"
        ;;
esac
