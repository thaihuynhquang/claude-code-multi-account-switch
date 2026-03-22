#!/usr/bin/env bats

load setup.bash

SWITCH="$PROJECT_ROOT/claude-switch.sh"

# ---------------------------------------------------------------------------
# save
# ---------------------------------------------------------------------------

@test "save: creates json with correct permissions" {
    run bash "$SWITCH" save work
    assert_success
    assert_output --partial "[OK] Saved as work"
    [ -f "$BACKUP_DIR/work.json" ]
    [ "$(file_perms "$BACKUP_DIR/work.json")" = "600" ]
}

@test "save: writes account name to .current" {
    run bash "$SWITCH" save work
    assert_success
    [ "$(cat "$CURRENT_FILE")" = "work" ]
}

@test "save: copies claude dir to account-dir" {
    touch "$CLAUDE_DIR/projects/myproj"
    run bash "$SWITCH" save work
    assert_success
    [ -f "$BACKUP_DIR/work-dir/projects/myproj" ]
}

@test "save: fails when .claude.json is missing" {
    rm "$CLAUDE_CONFIG"
    run bash "$SWITCH" save work
    assert_failure
    assert_output --partial "[ERROR]"
}

@test "save: fails with no account name argument" {
    run bash "$SWITCH" save
    assert_failure
    assert_output --partial "Usage:"
}

@test "save: rejects name with slash" {
    run bash "$SWITCH" save "bad/name"
    assert_failure
    assert_output --partial "[ERROR] Invalid account name"
}

@test "save: rejects name with space" {
    run bash "$SWITCH" save "my account"
    assert_failure
    assert_output --partial "[ERROR] Invalid account name"
}

@test "save: rejects name starting with dot" {
    run bash "$SWITCH" save ".hidden"
    assert_failure
    assert_output --partial "[ERROR] Invalid account name"
}

@test "save: allows name with hyphen and underscore" {
    run bash "$SWITCH" save "my-account_2"
    assert_success
    [ -f "$BACKUP_DIR/my-account_2.json" ]
}

@test "save: creates .gitignore in BACKUP_DIR" {
    run bash "$SWITCH" save work
    assert_success
    [ -f "$BACKUP_DIR/.gitignore" ]
    [ "$(cat "$BACKUP_DIR/.gitignore")" = "*" ]
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------

@test "list: shows saved accounts" {
    fixture_account work
    fixture_account personal
    run bash "$SWITCH" list
    assert_success
    assert_output --partial "work"
    assert_output --partial "personal"
}

@test "list: excludes dot-prefixed files" {
    fixture_account work
    touch "$BACKUP_DIR/.secret.json"
    run bash "$SWITCH" list
    assert_success
    refute_output --partial "secret"
}

@test "list: succeeds with no accounts" {
    run bash "$SWITCH" list
    assert_success
    assert_output --partial "Accounts:"
}

# ---------------------------------------------------------------------------
# status
# ---------------------------------------------------------------------------

@test "status: shows current account" {
    fixture_account work
    fixture_current work
    run bash "$SWITCH" status
    assert_success
    assert_output --partial "[OK] Current: work"
}

@test "status: shows unknown when .current missing" {
    run bash "$SWITCH" status
    assert_output --partial "[?] Unknown"
}

@test "status: shows unknown when .current has invalid name" {
    echo "bad/name" > "$CURRENT_FILE"
    run bash "$SWITCH" status
    assert_output --partial "[?] Unknown"
}

# ---------------------------------------------------------------------------
# remove
# ---------------------------------------------------------------------------

@test "remove: deletes json and dir" {
    fixture_account work
    run bash "$SWITCH" remove work
    assert_success
    assert_output --partial "[OK] Removed work"
    [ ! -f "$BACKUP_DIR/work.json" ]
    [ ! -d "$BACKUP_DIR/work-dir" ]
}

@test "remove: clears .current when it matches" {
    fixture_account work
    fixture_current work
    run bash "$SWITCH" remove work
    assert_success
    [ ! -f "$CURRENT_FILE" ]
}

@test "remove: does not clear .current when different account active" {
    fixture_account work
    fixture_account personal
    fixture_current personal
    run bash "$SWITCH" remove work
    assert_success
    [ "$(cat "$CURRENT_FILE")" = "personal" ]
}

@test "remove: fails for nonexistent account" {
    run bash "$SWITCH" remove ghost
    assert_failure
    assert_output --partial "[ERROR] Account 'ghost' not found"
}

@test "remove: fails with no argument" {
    run bash "$SWITCH" remove
    assert_failure
    assert_output --partial "Usage:"
}

# ---------------------------------------------------------------------------
# switch (bare account name)
# ---------------------------------------------------------------------------

@test "switch: restores json and updates .current" {
    fixture_account work
    fixture_account personal
    fixture_current personal
    run bash "$SWITCH" work
    assert_success
    assert_output --partial "[OK] Switched to work"
    [ "$(cat "$CURRENT_FILE")" = "work" ]
}

@test "switch: auto-saves current account before switching" {
    fixture_account work
    fixture_account personal
    fixture_current personal
    # Mutate the live config so we can detect auto-save
    echo '{"modified":true}' > "$CLAUDE_CONFIG"
    run bash "$SWITCH" work
    assert_success
    grep -q "modified" "$BACKUP_DIR/personal.json"
}

@test "switch: succeeds without a .current set (no auto-save)" {
    fixture_account work
    run bash "$SWITCH" work
    assert_success
    [ "$(cat "$CURRENT_FILE")" = "work" ]
}

@test "switch: prints error for unknown account" {
    run bash "$SWITCH" ghost
    assert_output --partial "[ERROR] Account 'ghost' not found"
}

@test "switch: skips dir restore when account-dir absent" {
    fixture_account work
    rm -rf "$BACKUP_DIR/work-dir"
    run bash "$SWITCH" work
    assert_success
}

# ---------------------------------------------------------------------------
# lock
# ---------------------------------------------------------------------------

@test "lock: stale lock (dead PID) is cleared automatically" {
    mkdir "$LOCK_DIR"
    echo "99999" > "$LOCK_DIR/pid"
    run bash "$SWITCH" save work
    assert_success
}

@test "lock: live lock blocks execution" {
    mkdir "$LOCK_DIR"
    echo "$$" > "$LOCK_DIR/pid"
    run bash "$SWITCH" save work
    assert_failure
    assert_output --partial "[ERROR] Another instance is running"
}

@test "lock: CLAUDE_LOCKED=1 bypasses lock check" {
    mkdir "$LOCK_DIR"
    echo "$$" > "$LOCK_DIR/pid"
    run env CLAUDE_LOCKED=1 bash "$SWITCH" save work
    assert_success
}

# ---------------------------------------------------------------------------
# help / edge cases
# ---------------------------------------------------------------------------

@test "help: no arguments prints usage" {
    run bash "$SWITCH"
    assert_success
    assert_output --partial "Usage:"
}

@test "help: --help prints commands" {
    run bash "$SWITCH" --help
    assert_success
    assert_output --partial "Commands:"
}
