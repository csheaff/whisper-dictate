#!/usr/bin/env bats

# Tests for the server mode (Unix socket daemon pattern).
# Uses a mock daemon so no real models or venvs are needed.

REPO_DIR="$BATS_TEST_DIRNAME/.."

setup() {
    export SOCK="$BATS_TEST_TMPDIR/test-server.sock"
    export PIDFILE="$BATS_TEST_TMPDIR/test-server.pid"
}

teardown() {
    # Clean up any leftover daemon
    if [ -f "$PIDFILE" ]; then
        kill "$(cat "$PIDFILE")" 2>/dev/null || true
        rm -f "$PIDFILE"
    fi
    rm -f "$SOCK"
}

# Helper: start the mock daemon
start_mock_daemon() {
    python3 "$BATS_TEST_DIRNAME/mock-daemon.py" "$SOCK" &
    local pid=$!
    echo "$pid" > "$PIDFILE"

    # Wait for socket to appear
    for i in $(seq 1 10); do
        [ -S "$SOCK" ] && return 0
        sleep 0.1
    done
    return 1
}

# ── Daemon lifecycle ──

@test "mock daemon starts and creates socket" {
    start_mock_daemon

    [ -S "$SOCK" ]
    [ -f "$PIDFILE" ]
    kill -0 "$(cat "$PIDFILE")"
}

@test "mock daemon responds to transcription requests" {
    command -v socat &>/dev/null || skip "socat not installed"
    start_mock_daemon

    result=$(echo "/tmp/test.wav" | socat - UNIX-CONNECT:"$SOCK")
    [[ "$result" == "mock transcription result" ]]
}

@test "mock daemon handles multiple requests" {
    command -v socat &>/dev/null || skip "socat not installed"
    start_mock_daemon

    result1=$(echo "/tmp/a.wav" | socat - UNIX-CONNECT:"$SOCK")
    result2=$(echo "/tmp/b.wav" | socat - UNIX-CONNECT:"$SOCK")
    [[ "$result1" == "mock transcription result" ]]
    [[ "$result2" == "mock transcription result" ]]
}

@test "daemon cleans up socket on SIGTERM" {
    start_mock_daemon

    [ -S "$SOCK" ]
    kill "$(cat "$PIDFILE")"
    sleep 0.2

    [ ! -S "$SOCK" ]
}

# ── Server wrapper logic ──

@test "transcribe fails with helpful message when server not running" {
    # Test each server script's transcribe command without a running server
    for server in transcribe-server backends/parakeet-server backends/moonshine-server; do
        run "$REPO_DIR/$server" transcribe /tmp/test.wav
        [ "$status" -eq 1 ]
        [[ "$output" == *"not running"* ]]
    done
}

@test "stop reports not running when no pidfile exists" {
    for server in transcribe-server backends/parakeet-server backends/moonshine-server; do
        run "$REPO_DIR/$server" stop
        [ "$status" -eq 0 ]
        [[ "$output" == *"Not running"* ]]
    done
}

@test "invalid subcommand shows usage" {
    for server in transcribe-server backends/parakeet-server backends/moonshine-server; do
        run "$REPO_DIR/$server" invalid
        [ "$status" -eq 1 ]
        [[ "$output" == *"Usage"* ]]
    done
}
