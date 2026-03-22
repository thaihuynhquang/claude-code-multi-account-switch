#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures"
USAGE_PY="$PROJECT_ROOT/claude-usage.py"

export PROJECT_ROOT FIXTURES_DIR USAGE_PY

load "$PROJECT_ROOT/tests/lib/bats-support/load.bash"
load "$PROJECT_ROOT/tests/lib/bats-assert/load.bash"

setup() {
    SANDBOX_HOME="$(mktemp -d)"
    export HOME="$SANDBOX_HOME"

    export BACKUP_DIR="$HOME/.claude-accounts"
    export CLAUDE_CONFIG="$HOME/.claude.json"
    export CLAUDE_DIR="$HOME/.claude"
    export CURRENT_FILE="$BACKUP_DIR/.current"
    export LOCK_DIR="$BACKUP_DIR/.lock.d"

    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    mkdir -p "$CLAUDE_DIR/projects"

    cp "$FIXTURES_DIR/sample.json" "$CLAUDE_CONFIG"
    chmod 600 "$CLAUDE_CONFIG"
}

teardown() {
    rm -rf "$SANDBOX_HOME"
}

# Create a pre-saved account in the sandbox (bypasses the save command)
fixture_account() {
    local name="$1"
    cp "$FIXTURES_DIR/sample.json" "$BACKUP_DIR/$name.json"
    chmod 600 "$BACKUP_DIR/$name.json"
    mkdir -p "$BACKUP_DIR/$name-dir/projects"
}

# Set the .current tracking file
fixture_current() {
    echo "$1" > "$CURRENT_FILE"
}

# Get file permissions as octal (macOS compatible)
file_perms() {
    stat -f "%Lp" "$1"
}
