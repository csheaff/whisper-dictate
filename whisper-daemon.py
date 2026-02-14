"""Whisper transcription daemon — loads model once, listens on a Unix socket."""
import os
import sys
import socket
import signal
from faster_whisper import WhisperModel

SOCK_PATH = sys.argv[1]
MODEL_NAME = sys.argv[2]
LANG = sys.argv[3]
DEVICE = sys.argv[4]
COMPUTE = sys.argv[5]

# Load model once
print(f"Loading faster-whisper {MODEL_NAME}...", flush=True)
model = WhisperModel(MODEL_NAME, device=DEVICE, compute_type=COMPUTE)
print("Model loaded.", flush=True)


def transcribe(audio_path):
    segments, _ = model.transcribe(audio_path, language=LANG, beam_size=5)
    return " ".join(seg.text.strip() for seg in segments).strip()


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
