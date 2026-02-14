# talktype

Push-to-talk speech-to-text for Linux. Bind a keyboard shortcut, press it to
start recording, press it again to transcribe and type the text wherever your
cursor is.

Transcription is pluggable — ships with
[faster-whisper](https://github.com/SYSTRAN/faster-whisper) by default, but you
can swap in any model or tool that reads audio and prints text.

## Requirements

- Linux with Wayland (GNOME, Sway, Hyprland, etc.)
- PipeWire (default on most modern distros)
- [ydotool](https://github.com/ReimuNotMoe/ydotool) for typing text
  (user must be in the `input` group — see Install)

For the default backend (faster-whisper):
- NVIDIA GPU with CUDA (or use CPU mode — see Configuration)

## Install

```bash
git clone https://github.com/csheaff/talktype.git
cd talktype
make install
```

This will:
1. Install system packages (`ydotool`, etc.)
2. Create a Python venv with `faster-whisper`
3. Symlink `talktype` into `~/.local/bin/`

### ydotool permissions

`ydotool` needs access to `/dev/uinput`. Add yourself to the `input` group:

```bash
sudo usermod -aG input $USER
echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/80-uinput.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Then **reboot** for the group change to take effect.

### Pre-download model (optional)

```bash
make model
```

## Setup

Bind `talktype` to a keyboard shortcut:

**GNOME:** Settings → Keyboard → Keyboard Shortcuts → Custom Shortcuts
- Name: `TalkType`
- Command: `talktype` (or full path `~/.local/bin/talktype`)
- Shortcut: your choice (e.g. `Super+D`, `F11`, etc.)

**Sway / Hyprland:** Add to your config:
```
bindsym $mod+d exec talktype
```

## Usage

1. Press your shortcut → notification says "Listening..."
2. Speak
3. Press the shortcut again → transcribes and types the text at your cursor

## Backends

Three backends are included. Each has a one-shot script (loads model per
invocation) and a server mode (loads model once, keeps it in memory).

### Whisper (default)

The default backend uses [faster-whisper](https://github.com/SYSTRAN/faster-whisper).
Best with a GPU.

```bash
# One-shot (default, no extra setup needed)
talktype

# Server mode (faster — model stays in memory)
transcribe-server start
export TALKTYPE_CMD="$HOME/code/talktype/transcribe-server transcribe"
```

| Variable | Default | Description |
|---|---|---|
| `WHISPER_MODEL` | `base` | `tiny`, `base`, `small`, `medium`, `large-v3-turbo` |
| `WHISPER_LANG` | `en` | Language code |
| `WHISPER_DEVICE` | `cuda` | `cuda` or `cpu` |
| `WHISPER_COMPUTE` | `float16` | `float16` (GPU), `int8` or `float32` (CPU) |

### Parakeet (GPU, best accuracy)

[NVIDIA Parakeet CTC 1.1B](https://huggingface.co/nvidia/parakeet-ctc-1.1b)
via HuggingFace Transformers. 1.1B params, excellent accuracy.

```bash
make parakeet

# Server mode (recommended — 4.2GB model)
backends/parakeet-server start
export TALKTYPE_CMD="$HOME/code/talktype/backends/parakeet-server transcribe"
```

### Moonshine (CPU, lightweight)

[Moonshine](https://huggingface.co/UsefulSensors/moonshine-base) by Useful
Sensors. 61.5M params, purpose-built for CPU/edge inference. Beats Whisper
models 28x its size.

```bash
make moonshine

# One-shot (fine for this small model)
export TALKTYPE_CMD="$HOME/code/talktype/backends/moonshine"

# Or server mode
backends/moonshine-server start
export TALKTYPE_CMD="$HOME/code/talktype/backends/moonshine-server transcribe"
```

Set `MOONSHINE_MODEL=UsefulSensors/moonshine-tiny` for an even smaller 27M
param model.

### Custom backends

Set `TALKTYPE_CMD` to any command that takes a WAV file path as its last
argument and prints text to stdout:

```bash
export TALKTYPE_CMD="/path/to/my-transcriber"
```

Your command will be called as: `$TALKTYPE_CMD /path/to/recording.wav`

It should print the transcribed text to stdout and exit. That's the only
contract — use whatever model, language, or runtime you want.

## How it works

```
[hotkey] → recording starts → [hotkey] → recording stops
                                            ↓
                                     $TALKTYPE_CMD audio.wav
                                            ↓
                                     ydotool type → text appears at cursor
```

The `talktype` script is ~80 lines of bash. Transcription backends are
swappable. Server mode uses Unix sockets to keep models in memory.

## License

MIT
