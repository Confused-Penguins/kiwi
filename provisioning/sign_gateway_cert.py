#!/usr/bin/env python3
"""
KIWI Gateway Certificate Signer
RFC 8032 Ed25519

Accepts an ESP32 Gateway Public Key (32 bytes hex) and Device ID,
constructs a canonical certificate payload, and signs it using the KIWI
Root CA private key.

Canonical Payload Format:
    KIWI-CERT:v1:<device_id>:<public_key_hex>:<issued_at>
"""

import argparse
import json
import sys
import time
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric import ed25519

DEFAULT_VAULT_FILE = Path(__file__).parent / "vault" / "root_private_key.json"


def canonical_cert_payload(device_id: str, public_key_hex: str, issued_at: int) -> bytes:
    """Deterministic, parser-independent canonical certificate string."""
    return f"KIWI-CERT:v1:{device_id}:{public_key_hex.lower()}:{issued_at}".encode("utf-8")


def sign_gateway(device_id: str,
                 gateway_pubkey_hex: str,
                 vault_path: Path = DEFAULT_VAULT_FILE,
                 issued_at: int = None,
                 output_file: Path = None) -> dict:
    if not vault_path.exists():
        raise FileNotFoundError(
            f"Root vault key not found at {vault_path}. Run generate_root_key.py first."
        )

    # Sanitize and validate inputs
    gateway_pubkey_hex = gateway_pubkey_hex.strip().lower()
    if len(gateway_pubkey_hex) != 64:
        raise ValueError(
            f"Invalid gateway public key length: {len(gateway_pubkey_hex)} hex characters (expected 64 for 32 bytes)."
        )

    try:
        bytes.fromhex(gateway_pubkey_hex)
    except ValueError:
        raise ValueError("Gateway public key must be valid hexadecimal.")

    if not device_id or ":" in device_id:
        raise ValueError("Device ID cannot be empty and must not contain colons ':'.")

    if issued_at is None:
        issued_at = int(time.time())

    # Load root private key
    with open(vault_path, "r") as f:
        vault_data = json.load(f)

    root_private_hex = vault_data["private_key_hex"]
    root_private_bytes = bytes.fromhex(root_private_hex)
    root_private_key = ed25519.Ed25519PrivateKey.from_private_bytes(root_private_bytes)

    # Construct canonical payload & sign
    payload = canonical_cert_payload(device_id, gateway_pubkey_hex, issued_at)
    signature_bytes = root_private_key.sign(payload)
    signature_hex = signature_bytes.hex()

    certificate = {
        "device_id": device_id,
        "public_key": gateway_pubkey_hex,
        "signature": signature_hex,
        "issued_at": issued_at
    }

    if output_file:
        output_file.parent.mkdir(parents=True, exist_ok=True)
        with open(output_file, "w") as f:
            json.dump(certificate, f, indent=2)
        print(f"[✓] Signed certificate written to: {output_file}")

    return certificate


def main():
    parser = argparse.ArgumentParser(description="Sign an ESP32 Gateway Public Key with KIWI Root CA")
    parser.add_argument("--device-id", required=True, help="Unique hardware device identifier (e.g. KIWI-GW-001)")
    parser.add_argument("--gateway-pubkey", required=True, help="64-character hex string of the gateway Ed25519 public key")
    parser.add_argument("--vault-file", type=Path, default=DEFAULT_VAULT_FILE, help="Path to root CA private key vault JSON")
    parser.add_argument("--issued-at", type=int, default=None, help="Epoch timestamp (default: current UTC time)")
    parser.add_argument("--output", type=Path, default=None, help="Path to save output certificate JSON")

    args = parser.parse_args()

    try:
        cert = sign_gateway(
            device_id=args.device_id,
            gateway_pubkey_hex=args.gateway_pubkey,
            vault_path=args.vault_file,
            issued_at=args.issued_at,
            output_file=args.output
        )
        print(json.dumps(cert, indent=2))
    except Exception as e:
        print(f"[-] Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
