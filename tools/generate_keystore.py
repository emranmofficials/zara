#!/usr/bin/env python3
"""Generate a release keystore for ZaRa and write android/key.properties.

Passwords are read from ZARA_STORE_PASSWORD / ZARA_KEY_PASSWORD, or prompted
interactively (hidden). The generated key.properties is gitignored.

Usage:
    python3 tools/generate_keystore.py
    ZARA_STORE_PASSWORD=... ZARA_KEY_PASSWORD=... python3 tools/generate_keystore.py --alias zara
"""
import argparse
import getpass
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
JKS = ANDROID / "app" / "zara-release.jks"
PROPS = ANDROID / "key.properties"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--alias", default="zara", help="key alias (default: zara)")
    ap.add_argument("--years", type=int, default=25, help="validity years")
    ap.add_argument("--force", action="store_true", help="overwrite an existing keystore")
    args = ap.parse_args()

    keytool = shutil.which("keytool")
    if keytool is None:
        print("keytool not found. Install a JDK (17+) and retry.")
        return 1
    if JKS.exists() and not args.force:
        print(f"Keystore already exists: {JKS}  (use --force to overwrite)")
        return 1

    store_pw = os.getenv("ZARA_STORE_PASSWORD") or getpass.getpass("Store password: ")
    key_pw = os.getenv("ZARA_KEY_PASSWORD") or getpass.getpass("Key password: ")
    if len(store_pw) < 6 or len(key_pw) < 6:
        print("Passwords must be at least 6 characters.")
        return 1

    JKS.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        keytool, "-genkeypair", "-v",
        "-keystore", str(JKS),
        "-alias", args.alias,
        "-keyalg", "RSA", "-keysize", "2048",
        "-validity", str(args.years * 365),
        "-storepass", store_pw,
        "-keypass", key_pw,
        "-dname", "CN=ZaRa, OU=ZaRa, O=ZaRa, L=Unknown, ST=Unknown, C=IN",
    ]
    print(f"Generating {JKS} ...")
    subprocess.run(cmd, check=True)

    PROPS.write_text(
        "storeFile=app/zara-release.jks\n"
        f"storePassword={store_pw}\n"
        f"keyAlias={args.alias}\n"
        f"keyPassword={key_pw}\n",
        encoding="utf-8",
    )
    print(f"Wrote {PROPS}")
    print("Keep both files secret. Build with: flutter build apk --release")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
