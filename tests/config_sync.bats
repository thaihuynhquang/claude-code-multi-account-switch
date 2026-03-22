#!/usr/bin/env bats

load setup.bash

CONFIG_SYNC="$PROJECT_ROOT/claude-config-sync.sh"

# ---------------------------------------------------------------------------
# directory merge (agents / skills / commands / memory / plugins)
# ---------------------------------------------------------------------------

@test "config-sync: merges agents from current account to saved accounts" {
    fixture_account work
    mkdir -p "$CLAUDE_DIR/agents"
    echo "name: MyAgent" > "$CLAUDE_DIR/agents/my-agent.md"
    run bash "$CONFIG_SYNC"
    assert_success
    [ -f "$BACKUP_DIR/work-dir/agents/my-agent.md" ]
}

@test "config-sync: merges agents from saved accounts into current" {
    fixture_account work
    mkdir -p "$BACKUP_DIR/work-dir/agents"
    echo "name: WorkAgent" > "$BACKUP_DIR/work-dir/agents/work-agent.md"
    run bash "$CONFIG_SYNC"
    assert_success
    [ -f "$CLAUDE_DIR/agents/work-agent.md" ]
}

@test "config-sync: merges skills across all accounts" {
    fixture_account work
    fixture_account personal
    mkdir -p "$BACKUP_DIR/work-dir/skills/skill-a"
    touch "$BACKUP_DIR/work-dir/skills/skill-a/SKILL.md"
    mkdir -p "$BACKUP_DIR/personal-dir/skills/skill-b"
    touch "$BACKUP_DIR/personal-dir/skills/skill-b/SKILL.md"
    run bash "$CONFIG_SYNC"
    assert_success
    [ -f "$CLAUDE_DIR/skills/skill-a/SKILL.md" ]
    [ -f "$CLAUDE_DIR/skills/skill-b/SKILL.md" ]
    [ -f "$BACKUP_DIR/work-dir/skills/skill-b/SKILL.md" ]
    [ -f "$BACKUP_DIR/personal-dir/skills/skill-a/SKILL.md" ]
}

@test "config-sync: current account wins on file conflict (cp -rn)" {
    fixture_account work
    mkdir -p "$CLAUDE_DIR/agents"
    echo "current-version" > "$CLAUDE_DIR/agents/shared.md"
    mkdir -p "$BACKUP_DIR/work-dir/agents"
    echo "work-version" > "$BACKUP_DIR/work-dir/agents/shared.md"
    run bash "$CONFIG_SYNC"
    assert_success
    [ "$(cat "$CLAUDE_DIR/agents/shared.md")" = "current-version" ]
    [ "$(cat "$BACKUP_DIR/work-dir/agents/shared.md")" = "current-version" ]
}

@test "config-sync: syncs commands directory" {
    fixture_account work
    mkdir -p "$CLAUDE_DIR/commands"
    touch "$CLAUDE_DIR/commands/my-cmd.md"
    run bash "$CONFIG_SYNC"
    assert_success
    [ -f "$BACKUP_DIR/work-dir/commands/my-cmd.md" ]
}

# ---------------------------------------------------------------------------
# single file sync (current account → all saved)
# ---------------------------------------------------------------------------

@test "config-sync: copies settings.json from current to all saved accounts" {
    fixture_account work
    fixture_account personal
    echo '{"model":"opus"}' > "$CLAUDE_DIR/settings.json"
    run bash "$CONFIG_SYNC"
    assert_success
    [ "$(cat "$BACKUP_DIR/work-dir/settings.json")" = '{"model":"opus"}' ]
    [ "$(cat "$BACKUP_DIR/personal-dir/settings.json")" = '{"model":"opus"}' ]
}

@test "config-sync: copies CLAUDE.md from current to all saved accounts" {
    fixture_account work
    echo "# My global instructions" > "$CLAUDE_DIR/CLAUDE.md"
    run bash "$CONFIG_SYNC"
    assert_success
    grep -q "My global instructions" "$BACKUP_DIR/work-dir/CLAUDE.md"
}

@test "config-sync: skips missing single files gracefully" {
    fixture_account work
    # No settings.json or CLAUDE.md in current dir
    rm -f "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/settings.local.json"
    run bash "$CONFIG_SYNC"
    assert_success
}

# ---------------------------------------------------------------------------
# output / edge cases
# ---------------------------------------------------------------------------

@test "config-sync: prints [OK] Synced config: per account" {
    fixture_account alpha
    fixture_account beta
    run bash "$CONFIG_SYNC"
    assert_success
    assert_output --partial "[OK] Synced config: alpha"
    assert_output --partial "[OK] Synced config: beta"
    assert_output --partial "[OK] Config sync complete!"
}

@test "config-sync: fails when no saved accounts exist" {
    run bash "$CONFIG_SYNC"
    assert_failure
    assert_output --partial "[ERROR] No saved accounts found"
}

@test "config-sync: unknown argument prints usage" {
    run bash "$CONFIG_SYNC" badarg
    assert_output --partial "Usage:"
}

@test "config-sync: stale lock is cleared automatically" {
    fixture_account work
    mkdir "$LOCK_DIR"
    echo "99999" > "$LOCK_DIR/pid"
    run bash "$CONFIG_SYNC"
    assert_success
}

@test "config-sync: live lock blocks execution" {
    fixture_account work
    mkdir "$LOCK_DIR"
    echo "$$" > "$LOCK_DIR/pid"
    run bash "$CONFIG_SYNC"
    assert_failure
    assert_output --partial "[ERROR] Another instance is running"
}
