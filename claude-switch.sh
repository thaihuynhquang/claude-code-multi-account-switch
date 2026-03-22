#!/bin/bash
umask 077

# Claude Code Multi-Account Switcher

CLAUDE_DIR="$HOME/.claude"
CLAUDE_CONFIG="$HOME/.claude.json"
BACKUP_DIR="$HOME/.claude-accounts"
CURRENT_FILE="$BACKUP_DIR/.current"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

if [ -z "$CLAUDE_LOCKED" ]; then
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
fi

# Prevent accidental git-tracking of token files
[ -f "$BACKUP_DIR/.gitignore" ] || echo "*" > "$BACKUP_DIR/.gitignore"

validate_name() {
    [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] || {
        echo "[ERROR] Invalid account name '$1'. Use only letters, numbers, _ and -"
        exit 1
    }
}

switch_account() {
    local account="$1"
    validate_name "$account"

    # Auto-save current account using state file
    local current
    current=$(cat "$CURRENT_FILE" 2>/dev/null)
    if [ -n "$current" ] && [[ "$current" =~ ^[a-zA-Z0-9_-]+$ ]] && [ -f "$BACKUP_DIR/$current.json" ]; then
        if [ -f "$CLAUDE_CONFIG" ]; then
            [ ! -L "$BACKUP_DIR/$current.json" ] || { echo "[ERROR] Symlink at $BACKUP_DIR/$current.json; aborting"; exit 1; }
            cp "$CLAUDE_CONFIG" "$BACKUP_DIR/$current.json"
            chmod 600 "$BACKUP_DIR/$current.json"
        fi
        if [ -d "$CLAUDE_DIR" ] && [ ! -L "$CLAUDE_DIR" ]; then
            local _tmp="$BACKUP_DIR/$current-dir.tmp.$$"
            cp -rP "$CLAUDE_DIR" "$_tmp"
            [ ! -L "$BACKUP_DIR/$current-dir" ] && rm -rf "$BACKUP_DIR/$current-dir"
            mv "$_tmp" "$BACKUP_DIR/$current-dir"
        fi
    fi

    # Switch
    if [ -f "$BACKUP_DIR/$account.json" ]; then
        [ ! -L "$BACKUP_DIR/$account.json" ] || { echo "[ERROR] Symlink at $BACKUP_DIR/$account.json; aborting"; exit 1; }
        cp "$BACKUP_DIR/$account.json" "$CLAUDE_CONFIG"
        chmod 600 "$CLAUDE_CONFIG"
        if [ -d "$BACKUP_DIR/$account-dir" ] && [ ! -L "$BACKUP_DIR/$account-dir" ]; then
            local _tmp="${CLAUDE_DIR}.tmp.$$"
            cp -rP "$BACKUP_DIR/$account-dir" "$_tmp"
            [ ! -L "$CLAUDE_DIR" ] && rm -rf "$CLAUDE_DIR"
            mv "$_tmp" "$CLAUDE_DIR"
        fi
        echo "$account" > "$CURRENT_FILE"
        echo "[OK] Switched to $account"
    else
        echo "[ERROR] Account '$account' not found. Save it first with: $0 save $account"
    fi
}

case "$1" in
    save)
        [ -z "$2" ] && { echo "Usage: $0 save <account_name>"; exit 1; }
        validate_name "$2"
        [ -f "$CLAUDE_CONFIG" ] || { echo "[ERROR] $CLAUDE_CONFIG not found. Run 'claude login' first"; exit 1; }
        [ ! -L "$BACKUP_DIR/$2.json" ] || { echo "[ERROR] Symlink at $BACKUP_DIR/$2.json; aborting"; exit 1; }
        cp "$CLAUDE_CONFIG" "$BACKUP_DIR/$2.json"
        chmod 600 "$BACKUP_DIR/$2.json"
        if [ -d "$CLAUDE_DIR" ] && [ ! -L "$CLAUDE_DIR" ]; then
            _tmp="$BACKUP_DIR/$2-dir.tmp.$$"
            cp -rP "$CLAUDE_DIR" "$_tmp"
            [ ! -L "$BACKUP_DIR/$2-dir" ] && rm -rf "$BACKUP_DIR/$2-dir"
            mv "$_tmp" "$BACKUP_DIR/$2-dir"
        fi
        echo "$2" > "$CURRENT_FILE"
        echo "[OK] Saved as $2"
        ;;
    list)
        echo "Accounts:"
        for f in "$BACKUP_DIR"/*.json; do
            [ -f "$f" ] || continue
            name=$(basename "$f" .json)
            [[ "$name" == .* ]] && continue
            echo "  - $name"
        done
        ;;
    status)
        current=$(cat "$CURRENT_FILE" 2>/dev/null)
        if [ -n "$current" ] && [[ "$current" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "[OK] Current: $current"
        else
            echo "[?] Unknown account"
        fi
        ;;
    remove)
        [ -z "$2" ] && { echo "Usage: $0 remove <account_name>"; exit 1; }
        validate_name "$2"
        [ ! -f "$BACKUP_DIR/$2.json" ] && { echo "[ERROR] Account '$2' not found"; exit 1; }
        rm -f "$BACKUP_DIR/$2.json"
        rm -rf "$BACKUP_DIR/$2-dir"
        current=$(cat "$CURRENT_FILE" 2>/dev/null)
        [ "$current" = "$2" ] && rm -f "$CURRENT_FILE"
        echo "[OK] Removed $2"
        ;;
    ""|help|-h|--help)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  save <name>   Save current account"
        echo "  remove <name> Remove account"
        echo "  <name>        Switch to account"
        echo "  list          List all accounts"
        echo "  status        Show current account"
        ;;
    *)
        switch_account "$1"
        ;;
esac
