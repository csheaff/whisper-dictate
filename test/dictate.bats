#!/usr/bin/env bats

# Test suite for the dictate script.
# All external commands (pw-record, ydotool, etc.) are stubbed
# with simple mocks so we can test the control flow in isolation.

setup() {
    export DICTATE_DIR="$BATS_TEST_TMPDIR/dictate"
    export DICTATE_CMD="$BATS_TEST_DIRNAME/mock-transcribe"

    # Put mocks on PATH before real commands
    export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"

    # The script under test
    DICTATE="$BATS_TEST_DIRNAME/../dictate"

    mkdir -p "$DICTATE_DIR"
}

teardown() {
    # Kill any leftover recording processes
    if [ -f "$DICTATE_DIR/rec.pid" ]; then
        kill "$(cat "$DICTATE_DIR/rec.pid")" 2>/dev/null || true
    fi
    rm -rf "$DICTATE_DIR"
}

# Helper: set up a fake "in-progress recording" state
start_fake_recording() {
    sleep 300 &
    echo $! > "$DICTATE_DIR/rec.pid"
    echo "audio data" > "$DICTATE_DIR/rec.wav"
}

# ── Recording lifecycle ──

@test "first invocation starts recording and creates pid file" {
    run "$DICTATE"
    [ "$status" -eq 0 ]
    [ -f "$DICTATE_DIR/rec.pid" ]

    # Verify the PID file contains a valid PID
    pid=$(cat "$DICTATE_DIR/rec.pid")
    kill -0 "$pid" 2>/dev/null
}

@test "second invocation stops recording and removes pid file" {
    start_fake_recording

    run "$DICTATE"
    [ "$status" -eq 0 ]
    [ ! -f "$DICTATE_DIR/rec.pid" ]
}

@test "audio file is cleaned up after transcription" {
    start_fake_recording

    run "$DICTATE"
    [ "$status" -eq 0 ]
    [ ! -f "$DICTATE_DIR/rec.wav" ]
}

# ── Transcription ──

@test "transcribed text is typed via ydotool" {
    start_fake_recording

    run "$DICTATE"
    [ "$status" -eq 0 ]

    # ydotool mock logs its args
    [[ "$(cat "$DICTATE_DIR/ydotool.log")" == *"hello world"* ]]
}

@test "custom DICTATE_CMD is used for transcription" {
    start_fake_recording
    export DICTATE_CMD="$BATS_TEST_DIRNAME/mock-transcribe-custom"

    run "$DICTATE"
    [ "$status" -eq 0 ]

    [[ "$(cat "$DICTATE_DIR/ydotool.log")" == *"custom output"* ]]
}

# ── Empty transcription ──

@test "exits cleanly when no speech is detected" {
    start_fake_recording
    export DICTATE_CMD="$BATS_TEST_DIRNAME/mock-transcribe-empty"

    run "$DICTATE"
    [ "$status" -eq 0 ]

    # ydotool should NOT have been called
    [ ! -f "$DICTATE_DIR/ydotool.log" ]
}

# ── Dependency checking ──

@test "fails when a required tool is missing" {
    # Create a minimal PATH with only the tools we want (no ydotool)
    local sparse="$BATS_TEST_TMPDIR/sparse_path"
    mkdir -p "$sparse"
    ln -sf "$(command -v pw-record)" "$sparse/pw-record"
    ln -sf "$(command -v notify-send)" "$sparse/notify-send"
    ln -sf "$(command -v bash)" "$sparse/bash"
    ln -sf "$(command -v mkdir)" "$sparse/mkdir"
    ln -sf "$(command -v cat)" "$sparse/cat"
    ln -sf "$(command -v kill)" "$sparse/kill"
    ln -sf "$(command -v sleep)" "$sparse/sleep"
    ln -sf "$(command -v echo)" "$sparse/echo"
    ln -sf "$(command -v rm)" "$sparse/rm"

    PATH="$sparse"

    run "$DICTATE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing"*"ydotool"* ]]
}
