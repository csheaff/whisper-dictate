"""Whisper transcription daemon — loads model once, listens on a Unix socket."""
import os
import sys
import socket
import signal
import logging
import time
from faster_whisper import WhisperModel

SOCK_PATH = sys.argv[1]
MODEL_NAME = sys.argv[2]
LANG = sys.argv[3]
DEVICE = sys.argv[4]
COMPUTE = sys.argv[5]

LOG_PATH = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "talktype-whisper.log")
logging.basicConfig(
    filename=LOG_PATH, level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("whisper-daemon")

# Load model once
log.info("Loading faster-whisper %s (device=%s, compute=%s)...", MODEL_NAME, DEVICE, COMPUTE)
print(f"Loading faster-whisper {MODEL_NAME}...", flush=True)
model = WhisperModel(MODEL_NAME, device=DEVICE, compute_type=COMPUTE)
print("Model loaded.", flush=True)
log.info("Model loaded.")


def transcribe(audio_path):
    segments, _ = model.transcribe(audio_path, language=LANG, beam_size=5)
    return " ".join(seg.text.strip() for seg in segments).strip()


def cleanup(*_):
    log.info("Shutting down (signal).")
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
            file_size = os.path.getsize(audio_path)
            log.info("Transcribing %s (%d bytes)...", audio_path, file_size)
            t0 = time.monotonic()
            text = transcribe(audio_path)
            elapsed = time.monotonic() - t0
            log.info("Done in %.1fs, %d chars: %s", elapsed, len(text),
                      text[:200] if text else "(empty)")
            conn.sendall(text.encode())
        else:
            log.warning("Bad path: %r", audio_path)
            conn.sendall(b"")
    except Exception as e:
        log.exception("Error during transcription")
        try:
            conn.sendall(b"")
        except Exception:
            pass
    finally:
        conn.close()
