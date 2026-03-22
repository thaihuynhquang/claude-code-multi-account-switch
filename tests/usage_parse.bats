#!/usr/bin/env bats

load setup.bash

RUNNER="$PROJECT_ROOT/tests/parse_usage_runner.py"

run_parse() {
    run env USAGE_PY="$USAGE_PY" python3 "$RUNNER" "$1"
}

@test "parse_usage: parses both session and week from full output" {
    run_parse "$FIXTURES_DIR/usage_full.txt"
    assert_success
    assert_output --partial '"session"'
    assert_output --partial '"week"'
    assert_output --partial "45%"
    assert_output --partial "78%"
}

@test "parse_usage: session only — week is null" {
    run_parse "$FIXTURES_DIR/usage_session_only.txt"
    assert_success
    assert_output --partial "30%"
    assert_output --partial '"week": null'
}

@test "parse_usage: fallback single-line format parses week" {
    run_parse "$FIXTURES_DIR/usage_week_only.txt"
    assert_success
    assert_output --partial "60%"
    assert_output --partial '"session": null'
}

@test "parse_usage: Asia/Saigo truncation is fixed to Asia/Saigon)" {
    run_parse "$FIXTURES_DIR/usage_fallback_saigon.txt"
    assert_success
    assert_output --partial "Asia/Saigon)"
    refute_output --partial "Asia/Saigo\""
}

@test "parse_usage: ANSI escape codes are stripped before matching" {
    run_parse "$FIXTURES_DIR/usage_ansi.txt"
    assert_success
    assert_output --partial "45%"
    assert_output --partial "78%"
}

@test "parse_usage: empty input returns both null" {
    run_parse "$FIXTURES_DIR/usage_empty.txt"
    assert_success
    assert_output '{"session": null, "week": null}'
}

@test "parse_usage: no input argument returns both null" {
    run env USAGE_PY="$USAGE_PY" python3 "$RUNNER"
    assert_success
    assert_output '{"session": null, "week": null}'
}
