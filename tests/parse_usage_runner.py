#!/usr/bin/env python3
"""Helper: load parse_usage from claude-usage.py and call it on the given file.

Usage: python3 parse_usage_runner.py <fixture_file>
Output: JSON {"session": ..., "week": ...}
"""
import sys
import json
import os
import importlib.util

usage_py = os.environ.get("USAGE_PY")
if not usage_py:
    print("USAGE_PY env var not set", file=sys.stderr)
    sys.exit(1)

spec = importlib.util.spec_from_file_location("claude_usage", usage_py)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

content = open(sys.argv[1]).read() if len(sys.argv) > 1 else ""
result = mod.parse_usage(content)
print(json.dumps(result))
