"""Parakeet transcription daemon — loads model once, listens on a Unix socket."""
import os
import sys
import socket
import signal
import torch
import soundfile as sf
from transformers import AutoProcessor, AutoModelForCTC

SOCK_PATH = sys.argv[1]

# Load model once
print("Loading parakeet-ctc-1.1b...", flush=True)
processor = AutoProcessor.from_pretrained("nvidia/parakeet-ctc-1.1b")
model = AutoModelForCTC.from_pretrained("nvidia/parakeet-ctc-1.1b", device_map="cuda")
print("Model loaded.", flush=True)


def transcribe(audio_path):
    audio, sr = sf.read(audio_path)
    inputs = processor(audio, sampling_rate=sr, return_tensors="pt")
    inputs = inputs.to(model.device, dtype=model.dtype)
    with torch.no_grad():
        logits = model(**inputs).logits
    predicted_ids = torch.argmax(logits, dim=-1)
    text = processor.batch_decode(predicted_ids, skip_special_tokens=True)
    return text[0].strip() if text else ""


def cleanup(*_):
    try:
        os.unlink(SOCK_PATH)
    except OSError:
        pass
    sys.exit(0)


signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

# Remove stale socket
if os.path.exists(SOCK_PATH):
    os.unlink(SOCK_PATH)

server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(SOCK_PATH)
server.listen(1)

while True:
    conn, _ = server.accept()
    try:
        audio_path = conn.recv(4096).decode().strip()
        if audio_path and os.path.isfile(audio_path):
            text = transcribe(audio_path)
            conn.sendall(text.encode())
        else:
            conn.sendall(b"")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr, flush=True)
        conn.sendall(b"")
    finally:
        conn.close()
