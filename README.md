# whisper-dictate

Push-to-talk speech-to-text for Wayland. Bind a keyboard shortcut, press it to
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
git clone https://github.com/csheaff/whisper-dictate.git
cd whisper-dictate
make install
```

This will:
1. Install system packages (`ydotool`, etc.)
2. Create a Python venv with `faster-whisper`
3. Symlink `dictate` into `~/.local/bin/`

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

Bind `dictate` to a keyboard shortcut:

**GNOME:** Settings → Keyboard → Keyboard Shortcuts → Custom Shortcuts
- Name: `Dictate`
- Command: `dictate` (or full path `~/.local/bin/dictate`)
- Shortcut: your choice (e.g. `Super+D`, `F11`, etc.)

**Sway / Hyprland:** Add to your config:
```
bindsym $mod+d exec dictate
```

## Usage

1. Press your shortcut → notification says "Listening..."
2. Speak
3. Press the shortcut again → transcribes and types the text at your cursor

## Custom transcription backends

Set `DICTATE_CMD` to any command that takes a WAV file path as its last
argument and prints text to stdout:

```bash
# whisper.cpp
export DICTATE_CMD="whisper-cpp -m /path/to/model.bin -f"

# Vosk
export DICTATE_CMD="vosk-transcriber --input"

# Any custom script
export DICTATE_CMD="/path/to/my-transcriber"
```

Your command will be called as: `$DICTATE_CMD /path/to/recording.wav`

It should print the transcribed text to stdout and exit. That's the only
contract — use whatever model, language, or runtime you want.

## Configuration

When using the default faster-whisper backend, these environment variables
apply:

| Variable | Default | Description |
|---|---|---|
| `WHISPER_MODEL` | `base` | Model size: `tiny`, `base`, `small`, `medium`, `large-v3` |
| `WHISPER_LANG` | `en` | Language code |
| `WHISPER_DEVICE` | `cuda` | `cuda` for GPU, `cpu` for CPU |
| `WHISPER_COMPUTE` | `float16` | `float16` for GPU, `int8` or `float32` for CPU |

For example, to use the `small` model on CPU:

```bash
WHISPER_MODEL=small WHISPER_DEVICE=cpu WHISPER_COMPUTE=int8 dictate
```

## How it works

```
[hotkey] → pw-record starts → [hotkey] → pw-record stops
                                            ↓
                                     $DICTATE_CMD audio.wav
                                            ↓
                                     ydotool type → text appears at cursor
```

The `dictate` script is ~80 lines of bash. The `transcribe` script is the
default backend (~15 lines of Python). No daemons, no services, no config
files.

## License

MIT
