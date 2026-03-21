#!/bin/bash

# Claude Next Account - Switch to next account

BACKUP_DIR="$HOME/.claude-accounts"
STATE_FILE="$BACKUP_DIR/.current_index"

mkdir -p "$BACKUP_DIR"
LOCK_FILE="$BACKUP_DIR/.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "[ERROR] Another instance is running"; exit 1; }

# Get accounts list using safe glob (avoids word-splitting on filenames)
accounts=()
for f in "$BACKUP_DIR"/*.json; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .json)
    [[ "$name" == .* ]] && continue
    accounts+=("$name")
done

total=${#accounts[@]}
[ $total -eq 0 ] && { echo "[ERROR] No accounts found"; exit 1; }

# Read current index
index=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
next=$(( (index + 1) % total ))

# Switch account
account="${accounts[$next]}"
CLAUDE_LOCKED=1 "$(dirname "$0")/claude-switch.sh" "$account"

# Save index
echo "$next" > "$STATE_FILE"
echo "Position: ($((next+1))/$total)"
