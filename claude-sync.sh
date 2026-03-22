#!/bin/bash
umask 077

# Claude Session Sync - Cross-sync sessions between ALL accounts

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
TMPFILES=()
trap 'rm -rf "$LOCK_DIR" "${TMPFILES[@]}"' EXIT

sync_cross() {
    # Collect all sessions from all accounts + current
    local tmp
    tmp=$(mktemp -d "$BACKUP_DIR/.tmp.XXXXXX")
    TMPFILES+=("$tmp")
    chmod 700 "$tmp"
    
    # From current account
    [ -d "$CLAUDE_DIR/projects" ] && cp -rP "$CLAUDE_DIR/projects"/* "$tmp/" 2>/dev/null
    
    # From all saved accounts
    for f in "$BACKUP_DIR"/*-dir/projects; do
        [ -d "$f" ] && cp -rPn "$f"/* "$tmp/" 2>/dev/null
    done
    
    # Distribute to all
    [ -d "$tmp" ] && [ "$(ls -A "$tmp" 2>/dev/null)" ] && {
        # To current
        mkdir -p "$CLAUDE_DIR/projects"
        cp -rP "$tmp"/* "$CLAUDE_DIR/projects/"
        
        # To all saved accounts
        for f in "$BACKUP_DIR"/*-dir; do
            [ -d "$f" ] || continue
            mkdir -p "$f/projects"
            cp -rP "$tmp"/* "$f/projects/"
            echo "[OK] Synced: $(basename "$f" -dir)"
        done
    }
    
    rm -rf "$tmp"
    echo "[OK] Cross-sync complete!"
}

case "$1" in
    sync|"")
        sync_cross
        ;;
    *)
        echo "Usage: $0 [sync]"
        echo "Cross-sync all sessions between ALL accounts"
        ;;
esac
