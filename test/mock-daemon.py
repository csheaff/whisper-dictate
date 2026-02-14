"""Mock transcription daemon for testing server mode."""
import os
import sys
import socket
import signal

SOCK_PATH = sys.argv[1]

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

print("Mock daemon ready.", flush=True)

while True:
    conn, _ = server.accept()
    try:
        audio_path = conn.recv(4096).decode().strip()
        conn.sendall(b"mock transcription result")
    except Exception:
        conn.sendall(b"")
    finally:
        conn.close()
