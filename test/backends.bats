#!/usr/bin/env bats

# Integration tests for transcription backends.
# Each test runs a real backend against a NASA audio clip and checks
# that the output contains expected words.
#
# Audio: Space Shuttle Discovery STS-133 final landing (2011), public domain.
# Expected transcript: "Wheel stop. Roger, wheel stop. Discovery, welcome
# back. A great ending to a new beginning."

FIXTURE="$BATS_TEST_DIRNAME/fixtures/nasa-wheelstop.wav"
REPO_DIR="$BATS_TEST_DIRNAME/.."

# ── Whisper (faster-whisper) ──

@test "whisper backend transcribes NASA audio" {
    [ -d "$REPO_DIR/.venv" ] || skip "whisper venv not installed (run: make venv)"

    run "$REPO_DIR/.venv/bin/python3" "$REPO_DIR/transcribe" base en cuda float16 "$FIXTURE"
    [ "$status" -eq 0 ]
    [[ "${output,,}" == *"welcome back"* ]]
}

# ── Parakeet (server mode) ──

@test "parakeet backend transcribes NASA audio" {
    [ -d "$REPO_DIR/backends/.parakeet-venv" ] || skip "parakeet venv not installed (run: make parakeet)"
    SOCK="${XDG_RUNTIME_DIR:-/tmp}/parakeet.sock"
    [ -S "$SOCK" ] || skip "parakeet server not running (run: backends/parakeet-server start)"

    run "$REPO_DIR/backends/parakeet-server" transcribe "$FIXTURE"
    [ "$status" -eq 0 ]
    [[ "${output,,}" == *"welcome back"* ]]
}

# ── Moonshine ──

@test "moonshine backend transcribes NASA audio" {
    [ -d "$REPO_DIR/backends/.moonshine-venv" ] || skip "moonshine venv not installed (run: make moonshine)"

    run "$REPO_DIR/backends/moonshine" "$FIXTURE"
    [ "$status" -eq 0 ]
    [[ "${output,,}" == *"welcome back"* ]]
}
