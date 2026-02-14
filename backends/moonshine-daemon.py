"""Moonshine transcription daemon — loads model once, listens on a Unix socket."""
import os
import sys
import socket
import signal
import soundfile as sf
from transformers import AutoProcessor, MoonshineForConditionalGeneration

SOCK_PATH = sys.argv[1]
MODEL_NAME = sys.argv[2]

# Load model once
print(f"Loading {MODEL_NAME}...", flush=True)
processor = AutoProcessor.from_pretrained(MODEL_NAME)
model = MoonshineForConditionalGeneration.from_pretrained(MODEL_NAME)
print("Model loaded.", flush=True)


def transcribe(audio_path):
    audio, sr = sf.read(audio_path)
    inputs = processor(audio, sampling_rate=sr, return_tensors="pt")
    generated_ids = model.generate(**inputs, max_new_tokens=200)
    texts = processor.batch_decode(generated_ids, skip_special_tokens=True)
    return texts[0].strip() if texts else ""


def cleanup(*_):
    try:
        os.unlink(SOCK_PATH)
    except OSError:
        pass
    sys.exit(0)


signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

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
