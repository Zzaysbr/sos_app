#!/usr/bin/env python3
"""Run checked-in Firestore rules against an isolated demo-only emulator."""
import json
import shlex
import socket
import subprocess
import tempfile
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    # Ask the OS for free loopback ports. Firebase fails if another process
    # claims them before startup; never stop an existing service to make room.
    reserved = [socket.socket() for _ in range(3)]
    try:
        for connection in reserved:
            connection.bind(("127.0.0.1", 0))
        firestore, hub, logging = [x.getsockname()[1] for x in reserved]
        with tempfile.TemporaryDirectory(prefix="emergency-rules-") as folder:
            folder = Path(folder)
            config = {
                "firestore": {"rules": str(root / "security-tests/firestore.rules")},
                "emulators": {
                    "firestore": {"host": "127.0.0.1", "port": firestore},
                    "hub": {"port": hub},
                    "logging": {"port": logging},
                    "ui": {"enabled": False},
                    "singleProjectMode": True,
                },
            }
            path = folder / "firebase.json"
            path.write_text(json.dumps(config))
            for connection in reserved:
                connection.close()
            test = shlex.join(["npm", "--prefix", str(root / "security-tests"), "test"])
            return subprocess.run(
                ["firebase", "emulators:exec", "--config", str(path),
                 "--project", "demo-off-grid-sos", "--only", "firestore", test],
                cwd=folder,
            ).returncode
    finally:
        for connection in reserved:
            connection.close()


if __name__ == "__main__":
    raise SystemExit(main())
