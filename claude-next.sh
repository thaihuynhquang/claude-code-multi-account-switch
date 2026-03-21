#!/bin/bash

# Claude Next Account - Switch to next account

BACKUP_DIR="$HOME/.claude-accounts"

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

# Get sorted accounts list
accounts=()
for f in "$BACKUP_DIR"/*.json; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .json)
    [[ "$name" == .* ]] && continue
    accounts+=("$name")
done

# Sort array for deterministic order
IFS=$'\n' accounts=($(sort <<<"${accounts[*]}")); unset IFS

total=${#accounts[@]}
[ $total -eq 0 ] && { echo "[ERROR] No accounts found"; exit 1; }

# Derive next index from current account name so manual switches stay in sync
current=$(cat "$BACKUP_DIR/.current" 2>/dev/null)
next_idx=0
for i in "${!accounts[@]}"; do
    if [ "${accounts[$i]}" = "$current" ]; then
        next_idx=$(( (i + 1) % total ))
        break
    fi
done

# Switch account
account="${accounts[$next_idx]}"
CLAUDE_LOCKED=1 "$(dirname "$0")/claude-switch.sh" "$account"
echo "Position: ($((next_idx+1))/$total)"
