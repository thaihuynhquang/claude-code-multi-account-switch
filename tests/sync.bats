#!/usr/bin/env bats

load setup.bash

SYNC="$PROJECT_ROOT/claude-sync.sh"

@test "sync: distributes current account projects to saved accounts" {
    fixture_account work
    fixture_account personal
    mkdir -p "$CLAUDE_DIR/projects/proj-A"
    touch "$CLAUDE_DIR/projects/proj-A/session.jsonl"
    run bash "$SYNC"
    assert_success
    [ -f "$BACKUP_DIR/work-dir/projects/proj-A/session.jsonl" ]
    [ -f "$BACKUP_DIR/personal-dir/projects/proj-A/session.jsonl" ]
}

@test "sync: pulls projects from saved accounts into current" {
    fixture_account work
    mkdir -p "$BACKUP_DIR/work-dir/projects/proj-B"
    touch "$BACKUP_DIR/work-dir/projects/proj-B/session.jsonl"
    run bash "$SYNC"
    assert_success
    [ -f "$CLAUDE_DIR/projects/proj-B/session.jsonl" ]
}

@test "sync: first-collected file wins (cp -rn no-clobber)" {
    fixture_account work
    mkdir -p "$CLAUDE_DIR/projects/proj-C"
    echo "current-version" > "$CLAUDE_DIR/projects/proj-C/data"
    mkdir -p "$BACKUP_DIR/work-dir/projects/proj-C"
    echo "work-version" > "$BACKUP_DIR/work-dir/projects/proj-C/data"
    run bash "$SYNC"
    assert_success
    # current account data was collected first, so it wins everywhere
    [ "$(cat "$CLAUDE_DIR/projects/proj-C/data")" = "current-version" ]
    [ "$(cat "$BACKUP_DIR/work-dir/projects/proj-C/data")" = "current-version" ]
}

@test "sync: prints [OK] Synced: for each account" {
    fixture_account alpha
    fixture_account beta
    touch "$CLAUDE_DIR/projects/x"
    run bash "$SYNC"
    assert_success
    assert_output --partial "[OK] Synced: alpha"
    assert_output --partial "[OK] Synced: beta"
    assert_output --partial "[OK] Cross-sync complete!"
}

@test "sync: exits cleanly with no projects anywhere" {
    fixture_account work
    rm -rf "$CLAUDE_DIR/projects"
    run bash "$SYNC"
    assert_success
    assert_output --partial "Cross-sync complete!"
}

@test "sync: explicit 'sync' argument works" {
    fixture_account work
    touch "$CLAUDE_DIR/projects/x"
    run bash "$SYNC" sync
    assert_success
    assert_output --partial "Cross-sync complete!"
}

@test "sync: unknown argument prints usage" {
    run bash "$SYNC" badarg
    assert_output --partial "Usage:"
}

@test "sync: stale lock is cleared automatically" {
    fixture_account work
    mkdir "$LOCK_DIR"
    echo "99999" > "$LOCK_DIR/pid"
    run bash "$SYNC"
    assert_success
}

@test "sync: live lock blocks execution" {
    fixture_account work
    mkdir "$LOCK_DIR"
    echo "$$" > "$LOCK_DIR/pid"
    run bash "$SYNC"
    assert_failure
    assert_output --partial "[ERROR] Another instance is running"
}
