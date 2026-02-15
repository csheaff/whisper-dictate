PREFIX ?= $(HOME)/.local

.PHONY: install uninstall deps venv test clean

# Full setup: system deps + venv + symlink into PATH
install: deps venv
	mkdir -p $(PREFIX)/bin
	ln -sf $(CURDIR)/talktype $(PREFIX)/bin/talktype
	@echo ""
	@echo "Installed to $(PREFIX)/bin/talktype"
	@echo "Now bind it to a keyboard shortcut in your desktop settings."

# Install system dependencies (requires sudo)
deps:
	sudo apt install -y wtype xdotool ydotool ffmpeg pipewire libnotify-bin python3-venv socat

# Create Python venv with faster-whisper (default backend)
venv: .venv/.done

.venv/.done:
	python3 -m venv .venv
	.venv/bin/pip install --upgrade pip
	.venv/bin/pip install faster-whisper
	touch .venv/.done

# Pre-download a Whisper model (optional, speeds up first use)
model:
	.venv/bin/python3 -c "from faster_whisper import WhisperModel; WhisperModel('base', device='cuda', compute_type='float16')"

# Install Parakeet backend (NVIDIA, via HuggingFace Transformers)
parakeet: backends/.parakeet-venv/.done

backends/.parakeet-venv/.done:
	python3 -m venv backends/.parakeet-venv
	backends/.parakeet-venv/bin/pip install --upgrade pip
	backends/.parakeet-venv/bin/pip install transformers torch soundfile librosa accelerate
	touch backends/.parakeet-venv/.done

# Install Moonshine backend (CPU-optimized, 61.5M params)
moonshine: backends/.moonshine-venv/.done

backends/.moonshine-venv/.done:
	python3 -m venv backends/.moonshine-venv
	backends/.moonshine-venv/bin/pip install --upgrade pip
	backends/.moonshine-venv/bin/pip install transformers torch soundfile
	touch backends/.moonshine-venv/.done

test:
	bats test/

uninstall:
	rm -f $(PREFIX)/bin/talktype

clean:
	rm -rf .venv
