#!/usr/bin/env bats

load setup.bash

NEXT="$PROJECT_ROOT/claude-next.sh"

@test "next: switches to first account (alpha) when no .current set" {
    fixture_account alpha
    fixture_account beta
    fixture_account gamma
    run bash "$NEXT"
    assert_success
    assert_output --partial "[OK] Switched to alpha"
    assert_output --partial "Position: (1/3)"
}

@test "next: round-robin from first to second" {
    fixture_account alpha
    fixture_account beta
    fixture_account gamma
    fixture_current alpha
    run bash "$NEXT"
    assert_success
    assert_output --partial "[OK] Switched to beta"
    assert_output --partial "Position: (2/3)"
}

@test "next: round-robin wraps from last to first" {
    fixture_account alpha
    fixture_account beta
    fixture_account gamma
    fixture_current gamma
    run bash "$NEXT"
    assert_success
    assert_output --partial "[OK] Switched to alpha"
    assert_output --partial "Position: (1/3)"
}

@test "next: single account always switches to itself" {
    fixture_account solo
    fixture_current solo
    run bash "$NEXT"
    assert_success
    assert_output --partial "[OK] Switched to solo"
    assert_output --partial "Position: (1/1)"
}

@test "next: ordering is alphabetical (deterministic)" {
    fixture_account zebra
    fixture_account alpha
    fixture_account mango
    fixture_current alpha
    run bash "$NEXT"
    assert_success
    assert_output --partial "Switched to mango"
}

@test "next: fails when no accounts exist" {
    run bash "$NEXT"
    assert_failure
    assert_output --partial "[ERROR] No accounts found"
}

@test "next: stale lock (dead PID) is cleared" {
    fixture_account alpha
    mkdir "$LOCK_DIR"
    echo "99999" > "$LOCK_DIR/pid"
    run bash "$NEXT"
    assert_success
}

@test "next: live lock blocks execution" {
    fixture_account alpha
    mkdir "$LOCK_DIR"
    echo "$$" > "$LOCK_DIR/pid"
    run bash "$NEXT"
    assert_failure
    assert_output --partial "[ERROR] Another instance is running"
}
