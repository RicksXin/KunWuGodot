#!/bin/zsh
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$TASK_ROOT/tools/run_resource_online_test.py"
