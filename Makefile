PREFIX ?= $(HOME)/.local

.PHONY: install uninstall deps venv test clean

# Full setup: system deps + venv + symlink into PATH
install: deps venv
	mkdir -p $(PREFIX)/bin
	ln -sf $(CURDIR)/dictate $(PREFIX)/bin/dictate
	@echo ""
	@echo "Installed to $(PREFIX)/bin/dictate"
	@echo "Now bind it to a keyboard shortcut in your desktop settings."

# Install system dependencies (requires sudo)
deps:
	sudo apt install -y ydotool pipewire libnotify-bin python3-venv

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

# Install Parakeet backend (NVIDIA NeMo)
parakeet: backends/.parakeet-venv/.done

backends/.parakeet-venv/.done:
	python3 -m venv backends/.parakeet-venv
	backends/.parakeet-venv/bin/pip install --upgrade pip
	backends/.parakeet-venv/bin/pip install transformers torch soundfile librosa accelerate
	touch backends/.parakeet-venv/.done

test:
	bats test/

uninstall:
	rm -f $(PREFIX)/bin/dictate

clean:
	rm -rf .venv
