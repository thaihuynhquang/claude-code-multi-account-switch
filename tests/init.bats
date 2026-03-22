#!/usr/bin/env bats

load setup.bash

INIT="$PROJECT_ROOT/init.sh"

@test "init: writes claude-switch alias to .zshrc when ZSH detected" {
    touch "$HOME/.zshrc"
    run env ZSH_VERSION=5.9 SHELL=/bin/zsh bash "$INIT"
    assert_success
    grep -q "claude-switch=" "$HOME/.zshrc"
}

@test "init: writes all four aliases to .zshrc" {
    touch "$HOME/.zshrc"
    run env ZSH_VERSION=5.9 SHELL=/bin/zsh bash "$INIT"
    assert_success
    grep -q "claude-switch=" "$HOME/.zshrc"
    grep -q "claude-sync="   "$HOME/.zshrc"
    grep -q "claude-next="   "$HOME/.zshrc"
    grep -q "claude-usage="  "$HOME/.zshrc"
}

@test "init: writes aliases to .bashrc when bash detected" {
    touch "$HOME/.bashrc"
    run env ZSH_VERSION="" SHELL=/bin/bash bash "$INIT"
    assert_success
    grep -q "claude-switch=" "$HOME/.bashrc"
}

@test "init: does not duplicate aliases on second run" {
    touch "$HOME/.zshrc"
    env ZSH_VERSION=5.9 SHELL=/bin/zsh bash "$INIT" > /dev/null
    run env ZSH_VERSION=5.9 SHELL=/bin/zsh bash "$INIT"
    assert_success
    count=$(grep -c "claude-switch=" "$HOME/.zshrc")
    [ "$count" -eq 1 ]
}

@test "init: prints installation confirmation" {
    touch "$HOME/.zshrc"
    run env ZSH_VERSION=5.9 SHELL=/bin/zsh bash "$INIT"
    assert_success
    assert_output --partial "Installed!"
}
