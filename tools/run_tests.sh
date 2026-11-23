#!/bin/sh
# Runs the automated checks with a hard time limit (a script parse error would
# otherwise leave Godot idling forever). Usage: tools/run_tests.sh [path-to-godot]
GODOT="${1:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.." || exit 1
"$GODOT" --headless --path . res://tests/test_runner.tscn &
PID=$!
( sleep 360; kill "$PID" 2>/dev/null && echo "TIMEOUT: tests were stopped after 6 minutes" ) &
WATCH=$!
wait "$PID"
CODE=$?
kill "$WATCH" 2>/dev/null
exit $CODE
