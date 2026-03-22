#!/bin/bash

# Init Claude Code Multi-Account Switcher

DIR="$(cd "$(dirname "$0")" && pwd)"

chmod +x "$DIR/claude-switch.sh" "$DIR/claude-sync.sh" "$DIR/claude-next.sh" "$DIR/claude-usage.py" "$DIR/claude-config-sync.sh"

# Detect shell and pick the right rc file
if [ -n "$ZSH_VERSION" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    RC_FILE="$HOME/.zshrc"
else
    RC_FILE="$HOME/.bashrc"
fi

# Add aliases — single quotes protect all special chars in the path
# Handle literal single quotes in the path via '"'"' substitution
safe_dir="${DIR//\'/\'\"\'\"\'}"
grep -q "claude-switch=" "$RC_FILE" || echo "alias claude-switch='${safe_dir}/claude-switch.sh'" >> "$RC_FILE"
grep -q "claude-sync=" "$RC_FILE" || echo "alias claude-sync='${safe_dir}/claude-sync.sh'" >> "$RC_FILE"
grep -q "claude-next=" "$RC_FILE" || echo "alias claude-next='${safe_dir}/claude-next.sh'" >> "$RC_FILE"
grep -q "claude-usage=" "$RC_FILE" || echo "alias claude-usage='python3 ${safe_dir}/claude-usage.py'" >> "$RC_FILE"
grep -q "claude-config-sync=" "$RC_FILE" || echo "alias claude-config-sync='${safe_dir}/claude-config-sync.sh'" >> "$RC_FILE"

echo "Installed! Aliases written to $RC_FILE"
echo ""
echo "Run this to activate: source $RC_FILE"
echo "   Or restart your terminal"
echo ""
echo "Commands:"
echo "  claude-switch <name>  - Switch account"
echo "  claude-switch save <name> - Save current account"
echo "  claude-switch list    - List accounts"
echo "  claude-sync           - Sync sessions between all accounts"
echo "  claude-next           - Switch to next account"
echo "  claude-usage          - View usage of all accounts"
echo "  claude-config-sync    - Sync skills, agents, settings across all accounts"
