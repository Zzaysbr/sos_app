#!/usr/bin/env python3
"""Reject a Debug iOS artifact before standalone/Home Screen installation."""
import argparse
import json
import plistlib
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--bundle-id", default="com.n1cxltine.sosapp")
    parser.add_argument("--build-number", required=True)
    args = parser.parse_args()
    info = plistlib.loads((args.app / "Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != args.bundle_id:
        parser.error("Unexpected application identity; do not install.")
    if info.get("CFBundleVersion") != args.build_number:
        parser.error("Unexpected build number; do not install.")
    if any(args.app.rglob("kernel_blob.bin")):
        parser.error("Debug kernel found. Build --profile or --release for Home Screen launch.")
    if not (args.app / "Frameworks/App.framework/App").is_file():
        parser.error("Compiled application framework missing; do not install.")
    signed = subprocess.run(
        ["codesign", "--verify", "--deep", "--strict", str(args.app)],
        capture_output=True,
    )
    if signed.returncode:
        parser.error("Code signature verification failed; do not install.")
    print(json.dumps({"standalone_preflight": "passed", "build": args.build_number,
                      "debug_kernel_absent": True, "signature_valid": True}))


if __name__ == "__main__":
    main()
