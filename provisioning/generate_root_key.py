#!/usr/bin/env python3
"""
KIWI Root CA Keypair Generator
RFC 8032 Ed25519

This script generates the authoritative offline KIWI Root CA keypair.
The private key generated here MUST NEVER be committed to version control,
transferred over untrusted networks, or embedded into firmware or client apps.
Only the PUBLIC key is safe to embed into the mobile client.
"""

import argparse
import json
import os
import sys
import stat
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization

VAULT_DIR = Path(__file__).parent / "vault"
PRIVATE_KEY_FILE = VAULT_DIR / "root_private_key.json"
PUBLIC_KEY_HEX_FILE = VAULT_DIR / "root_public_key.hex"
PUBLIC_KEY_PEM_FILE = VAULT_DIR / "root_public_key.pem"


def generate_root_keypair(force: bool = False):
    VAULT_DIR.mkdir(parents=True, exist_ok=True)

    if PRIVATE_KEY_FILE.exists() and not force:
        print(f"[!] Warning: Root key already exists at: {PRIVATE_KEY_FILE}")
        print("    Use --force to overwrite if you intentionally want to regenerate.")
        sys.exit(1)

    # 1. Generate Ed25519 Root Private Key
    private_key = ed25519.Ed25519PrivateKey.generate()
    public_key = private_key.public_key()

    # Extract raw 32 bytes
    private_raw = private_key.private_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PrivateFormat.Raw,
        encryption_algorithm=serialization.NoEncryption()
    )
    public_raw = public_key.public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw
    )

    private_hex = private_raw.hex()
    public_hex = public_raw.hex()

    # 2. Save Sensitive Private Key with strict permissions (0600)
    vault_payload = {
        "NOTICE": "CRITICAL SECURITY RISK: SENSITIVE ROOT CA PRIVATE KEY. NEVER COMMIT OR DISTRIBUTE.",
        "algorithm": "Ed25519 (RFC 8032)",
        "role": "KIWI Root Certificate Authority",
        "private_key_hex": private_hex,
        "public_key_hex": public_hex
    }

    # Atomic write with 0600 permissions
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    mode = stat.S_IRUSR | stat.S_IWUSR  # 0600
    fd = os.open(str(PRIVATE_KEY_FILE), flags, mode)
    with os.fdopen(fd, "w") as f:
        json.dump(vault_payload, f, indent=2)

    # 3. Save Public Key exports
    PUBLIC_KEY_HEX_FILE.write_text(public_hex + "\n")
    public_pem = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    PUBLIC_KEY_PEM_FILE.write_bytes(public_pem)

    print("=" * 70)
    print(" [✓] KIWI Root CA Keypair Generated Successfully")
    print("=" * 70)
    print(f" Vault Private Key (CONFIDENTIAL): {PRIVATE_KEY_FILE}")
    print(f" Public Key (Public Safe)       : {PUBLIC_KEY_HEX_FILE}")
    print("-" * 70)
    print(f" Root Public Key (Hex 32-bytes) :\n {public_hex}")
    print("-" * 70)
    print(" Direct Dart Constant for lib/constants/security_constants.dart:")
    print(f' const String kKiwiRootPublicKeyHex = "{public_hex}";')
    print("=" * 70)


def main():
    parser = argparse.ArgumentParser(description="Generate KIWI Root Ed25519 Keypair")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing root keys in vault if present"
    )
    args = parser.parse_args()
    generate_root_keypair(force=args.force)


if __name__ == "__main__":
    main()
