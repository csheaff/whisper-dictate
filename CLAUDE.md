# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is talktype

Push-to-talk speech-to-text for Linux. Press a hotkey to record, press again to transcribe and type at cursor. No GUI — just a keyboard shortcut bound to the `talktype` script. Works on Wayland (GNOME, Sway, Hyprland) and X11.

## Build and install

```bash
make install      # Full setup: system deps + Python venv + symlink to ~/.local/bin/talktype
make deps         # System packages only (requires sudo): ydotool, ffmpeg, pipewire, etc.
make venv         # Python venv with faster-whisper only
make parakeet     # Install Parakeet backend venv (in backends/.parakeet-venv/)
make moonshine    # Install Moonshine backend venv (in backends/.moonshine-venv/)
make model        # Pre-download Whisper model
make clean        # Remove .venv
make uninstall    # Remove ~/.local/bin/talktype symlink
```

## Testing

Tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System):

```bash
make test                    # Run all tests
bats test/talktype.bats      # Core tests (recording lifecycle, transcription, error handling)
bats test/server.bats        # Server mode tests (daemon lifecycle, socket communication)
bats test/backends.bats      # Integration tests against real backends + NASA audio fixture
```

Tests use mocks in `test/mocks/` to avoid requiring actual GPU, models, or system tools. The mock daemon (`test/mock-daemon.py`) simulates server backends.

## Linting

CI runs ShellCheck on all Bash scripts and Python syntax checks on all Python files:

```bash
shellcheck talktype transcribe-server backends/*-server
python3 -m py_compile transcribe whisper-daemon.py backends/*-daemon.py
```

## Architecture

**Core flow:** hotkey → `talktype` (Bash) → record audio (ffmpeg/pw-record) → call `$TALKTYPE_CMD` with WAV path → type result via `type_text` (wtype/ydotool/xdotool).

**Main script** (`talktype`, ~160 lines Bash): manages recording state via PID file (`$TALKTYPE_DIR/rec.pid`), sends desktop notifications, delegates transcription to `$TALKTYPE_CMD`.

**Backend pattern — two modes per backend:**
- **Direct invocation** (`transcribe`, `backends/parakeet`, `backends/moonshine`): Python scripts that load model, transcribe, exit. Simple but slow (model reload each time).
- **Server mode** (`transcribe-server`, `backends/*-server` + `*-daemon.py`): Bash wrapper manages a Python Unix socket daemon that keeps the model in memory. Subcommands: `start`, `stop`, `transcribe`. Auto-starts daemon if not running.

**Adding a custom backend:** Any executable that takes a WAV file path as its last argument and prints text to stdout. Set `TALKTYPE_CMD` in config.

## Configuration

Config file: `~/.config/talktype/config` (sourced as shell script by `talktype`). Key variables:

- `TALKTYPE_CMD` — transcription command (default: direct faster-whisper via `transcribe`)
- `TALKTYPE_VENV` — Python venv path (default: `.venv` in script dir)
- `TALKTYPE_DIR` — runtime dir for PID/audio files (default: `$XDG_RUNTIME_DIR/talktype`)
- `TALKTYPE_TYPE_CMD` — typing tool (`auto`, `wtype`, `ydotool`, `xdotool`, or custom command; default: `auto`)
- `WHISPER_MODEL`, `WHISPER_LANG`, `WHISPER_DEVICE`, `WHISPER_COMPUTE` — Whisper settings

## Key conventions

- Core is intentionally pure Bash. Python is only used for ML model invocation.
- Follows Unix philosophy: small scripts, stdin/stdout interfaces, pluggable components.
- Server daemons communicate via Unix sockets using `socat`.
- State files (PID, audio, notification ID) live in `$TALKTYPE_DIR` (XDG runtime dir).
