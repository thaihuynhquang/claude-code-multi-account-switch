#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BATS="$SCRIPT_DIR/tests/lib/bats-core/bin/bats"

if [ ! -f "$BATS" ]; then
    echo "[ERROR] bats-core not found. Run:"
    echo "  git submodule update --init --recursive"
    exit 1
fi

SUITE="${1:-all}"

case "$SUITE" in
    switch)      exec "$BATS" "$SCRIPT_DIR/tests/switch.bats" ;;
    next)        exec "$BATS" "$SCRIPT_DIR/tests/next.bats" ;;
    sync)        exec "$BATS" "$SCRIPT_DIR/tests/sync.bats" ;;
    init)        exec "$BATS" "$SCRIPT_DIR/tests/init.bats" ;;
    usage)       exec "$BATS" "$SCRIPT_DIR/tests/usage_parse.bats" ;;
    config-sync) exec "$BATS" "$SCRIPT_DIR/tests/config_sync.bats" ;;
    all)
        exec "$BATS" \
            "$SCRIPT_DIR/tests/switch.bats" \
            "$SCRIPT_DIR/tests/next.bats" \
            "$SCRIPT_DIR/tests/sync.bats" \
            "$SCRIPT_DIR/tests/init.bats" \
            "$SCRIPT_DIR/tests/usage_parse.bats" \
            "$SCRIPT_DIR/tests/config_sync.bats"
        ;;
    *)
        echo "Usage: $0 [switch|next|sync|init|usage|config-sync|all]"
        exit 1
        ;;
esac
