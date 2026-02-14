#!/usr/bin/env bats

# Test suite for the talktype script.
# All external commands (pw-record, ydotool, etc.) are stubbed
# with simple mocks so we can test the control flow in isolation.

setup() {
    export TALKTYPE_CONFIG="/dev/null"
    export TALKTYPE_DIR="$BATS_TEST_TMPDIR/talktype"
    export TALKTYPE_CMD="$BATS_TEST_DIRNAME/mock-transcribe"

    # Put mocks on PATH before real commands
    export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"

    # The script under test
    TALKTYPE="$BATS_TEST_DIRNAME/../talktype"

    mkdir -p "$TALKTYPE_DIR"
}

teardown() {
    # Kill any leftover recording processes
    if [ -f "$TALKTYPE_DIR/rec.pid" ]; then
        kill "$(cat "$TALKTYPE_DIR/rec.pid")" 2>/dev/null || true
    fi
    rm -rf "$TALKTYPE_DIR"
}

# Helper: set up a fake "in-progress recording" state
start_fake_recording() {
    sleep 300 &
    echo $! > "$TALKTYPE_DIR/rec.pid"
    echo "audio data" > "$TALKTYPE_DIR/rec.wav"
}

# ── Recording lifecycle ──

@test "first invocation starts recording and creates pid file" {
    run "$TALKTYPE"
    [ "$status" -eq 0 ]
    [ -f "$TALKTYPE_DIR/rec.pid" ]

    # Verify the PID file contains a valid PID
    pid=$(cat "$TALKTYPE_DIR/rec.pid")
    kill -0 "$pid" 2>/dev/null
}

@test "second invocation stops recording and removes pid file" {
    start_fake_recording

    run "$TALKTYPE"
    [ "$status" -eq 0 ]
    [ ! -f "$TALKTYPE_DIR/rec.pid" ]
}

@test "audio file is cleaned up after transcription" {
    start_fake_recording

    run "$TALKTYPE"
    [ "$status" -eq 0 ]
    [ ! -f "$TALKTYPE_DIR/rec.wav" ]
}

# ── Transcription ──

@test "transcribed text is typed via ydotool" {
    start_fake_recording

    run "$TALKTYPE"
    [ "$status" -eq 0 ]

    # ydotool mock logs its args
    [[ "$(cat "$TALKTYPE_DIR/ydotool.log")" == *"hello world"* ]]
}

@test "custom TALKTYPE_CMD is used for transcription" {
    start_fake_recording
    export TALKTYPE_CMD="$BATS_TEST_DIRNAME/mock-transcribe-custom"

    run "$TALKTYPE"
    [ "$status" -eq 0 ]

    [[ "$(cat "$TALKTYPE_DIR/ydotool.log")" == *"custom output"* ]]
}

# ── Empty transcription ──

@test "exits cleanly when no speech is detected" {
    start_fake_recording
    export TALKTYPE_CMD="$BATS_TEST_DIRNAME/mock-transcribe-empty"

    run "$TALKTYPE"
    [ "$status" -eq 0 ]

    # ydotool should NOT have been called
    [ ! -f "$TALKTYPE_DIR/ydotool.log" ]
}

# ── Error handling ──

@test "stale pid file with dead process still transcribes" {
    # Simulate a crashed recording: PID file points to a dead process
    echo "99999" > "$TALKTYPE_DIR/rec.pid"
    echo "audio data" > "$TALKTYPE_DIR/rec.wav"

    run "$TALKTYPE"
    [ "$status" -eq 0 ]

    # Should have cleaned up and transcribed
    [ ! -f "$TALKTYPE_DIR/rec.pid" ]
    [[ "$(cat "$TALKTYPE_DIR/ydotool.log")" == *"hello world"* ]]
}

@test "transcription command failure is handled" {
    start_fake_recording
    export TALKTYPE_CMD="$BATS_TEST_DIRNAME/mock-transcribe-fail"

    run "$TALKTYPE"

    # Script should fail (set -e catches the non-zero exit)
    [ "$status" -ne 0 ]

    # ydotool should NOT have been called
    [ ! -f "$TALKTYPE_DIR/ydotool.log" ]
}

# ── Recorder selection ──

@test "ffmpeg is preferred over pw-record when available" {
    run "$TALKTYPE"
    [ "$status" -eq 0 ]
    [ -f "$TALKTYPE_DIR/recorder.log" ]

    [[ "$(cat "$TALKTYPE_DIR/recorder.log")" == "ffmpeg" ]]
}

@test "pw-record is used when ffmpeg is not available" {
    # Remove ffmpeg from PATH by creating a sparse PATH without it
    local sparse="$BATS_TEST_TMPDIR/no_ffmpeg"
    mkdir -p "$sparse"

    # Copy all mocks except ffmpeg
    for mock in "$BATS_TEST_DIRNAME"/mocks/*; do
        name=$(basename "$mock")
        [ "$name" = "ffmpeg" ] && continue
        ln -sf "$mock" "$sparse/$name"
    done

    # Add essential system tools
    for cmd in bash mkdir cat kill sleep echo rm wait; do
        local path
        path=$(command -v "$cmd" 2>/dev/null) && ln -sf "$path" "$sparse/$cmd"
    done

    PATH="$sparse"

    run "$TALKTYPE"
    [ "$status" -eq 0 ]
    [ -f "$TALKTYPE_DIR/recorder.log" ]

    [[ "$(cat "$TALKTYPE_DIR/recorder.log")" == "pw-record" ]]
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

    run "$TALKTYPE"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing"*"ydotool"* ]]
}
