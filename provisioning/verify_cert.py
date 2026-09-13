#!/usr/bin/env python3
"""
KIWI Certificate Verifier
Verifies an ESP32 Gateway certificate against the Root CA public key and revocation list.
"""

import argparse
import json
import sys
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.exceptions import InvalidSignature

DEFAULT_ROOT_PUB_FILE = Path(__file__).parent / "vault" / "root_public_key.hex"
DEFAULT_CRL_FILE = Path(__file__).parent / "revocation_list.json"


def canonical_cert_payload(device_id: str, public_key_hex: str, issued_at: int) -> bytes:
    return f"KIWI-CERT:v1:{device_id}:{public_key_hex.lower()}:{issued_at}".encode("utf-8")


def verify_certificate(cert_data: dict,
                       root_pubkey_hex: str,
                       crl_file: Path = None) -> tuple[bool, str]:
    # 1. Parse & validate fields
    required = ["device_id", "public_key", "signature", "issued_at"]
    for f in required:
        if f not in cert_data:
            return False, f"Missing required certificate field: '{f}'"

    device_id = cert_data["device_id"]
    gateway_pubkey_hex = cert_data["public_key"].lower()
    signature_hex = cert_data["signature"].lower()
    issued_at = int(cert_data["issued_at"])

    # 2. Check Revocation
    if crl_file and crl_file.exists():
        with open(crl_file, "r") as f:
            crl = json.load(f)
        for entry in crl.get("revoked_devices", []):
            if entry["device_id"] == device_id:
                return False, f"Device ID '{device_id}' is REVOKED (Reason: {entry.get('reason')})"

    # 3. Verify Ed25519 Signature
    try:
        root_pub_bytes = bytes.fromhex(root_pubkey_hex)
        root_public_key = ed25519.Ed25519PublicKey.from_public_bytes(root_pub_bytes)

        payload = canonical_cert_payload(device_id, gateway_pubkey_hex, issued_at)
        sig_bytes = bytes.fromhex(signature_hex)

        root_public_key.verify(sig_bytes, payload)
        return True, f"Valid certificate for '{device_id}' signed by KIWI Root CA"
    except InvalidSignature:
        return False, "Cryptographic signature verification FAILED (tampered certificate or wrong root key)"
    except Exception as e:
        return False, f"Verification error: {e}"


def main():
    parser = argparse.ArgumentParser(description="Verify a KIWI Gateway Certificate")
    parser.add_argument("cert_file", type=Path, help="Path to gateway certificate JSON")
    parser.add_argument("--root-pubkey", type=str, default=None, help="Root public key hex string")
    parser.add_argument("--root-pubkey-file", type=Path, default=DEFAULT_ROOT_PUB_FILE, help="Path to root public key hex file")
    parser.add_argument("--crl-file", type=Path, default=DEFAULT_CRL_FILE, help="Path to revocation_list.json")

    args = parser.parse_args()

    if args.root_pubkey:
        root_pubkey_hex = args.root_pubkey.strip()
    elif args.root_pubkey_file.exists():
        root_pubkey_hex = args.root_pubkey_file.read_text().strip()
    else:
        print("[-] Error: Root public key not provided and default file not found.", file=sys.stderr)
        sys.exit(1)

    with open(args.cert_file, "r") as f:
        cert_data = json.load(f)

    valid, message = verify_certificate(cert_data, root_pubkey_hex, args.crl_file)
    if valid:
        print(f"[✓] SUCCESS: {message}")
        sys.exit(0)
    else:
        print(f"[-] FAILED: {message}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
