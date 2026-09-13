#!/usr/bin/env python3
"""
KIWI Revocation List Manager
Maintains the authoritative Certificate Revocation List (CRL) for KIWI gateways.
"""

import argparse
import json
import sys
import time
from pathlib import Path

DEFAULT_CRL_FILE = Path(__file__).parent / "revocation_list.json"


def load_crl(crl_path: Path) -> dict:
    if not crl_path.exists():
        return {
            "version": 1,
            "updated_at": int(time.time()),
            "description": "KIWI Authoritative Certificate Revocation List (CRL)",
            "revoked_devices": []
        }
    with open(crl_path, "r") as f:
        return json.load(f)


def save_crl(crl_path: Path, crl_data: dict):
    crl_data["version"] = crl_data.get("version", 0) + 1
    crl_data["updated_at"] = int(time.time())
    with open(crl_path, "w") as f:
        json.dump(crl_data, f, indent=2)
    print(f"[✓] Revocation list updated (v{crl_data['version']}) saved to {crl_path}")


def add_revocation(crl_path: Path, device_id: str, reason: str = "Unspecified"):
    crl = load_crl(crl_path)
    revoked = crl.setdefault("revoked_devices", [])

    for entry in revoked:
        if entry["device_id"] == device_id:
            print(f"[!] Device '{device_id}' is already revoked since {entry.get('revoked_at')}.")
            return

    revoked.append({
        "device_id": device_id,
        "revoked_at": int(time.time()),
        "reason": reason
    })
    save_crl(crl_path, crl)
    print(f"[✓] Device '{device_id}' added to revocation list.")


def remove_revocation(crl_path: Path, device_id: str):
    crl = load_crl(crl_path)
    revoked = crl.get("revoked_devices", [])

    initial_len = len(revoked)
    revoked = [r for r in revoked if r["device_id"] != device_id]

    if len(revoked) == initial_len:
        print(f"[!] Device '{device_id}' was not found in the revocation list.")
        return

    crl["revoked_devices"] = revoked
    save_crl(crl_path, crl)
    print(f"[✓] Device '{device_id}' removed from revocation list.")


def list_revocations(crl_path: Path):
    crl = load_crl(crl_path)
    revoked = crl.get("revoked_devices", [])
    print(f"KIWI CRL v{crl.get('version', 1)} — Last Updated: {crl.get('updated_at')}")
    print(f"Total Revoked Gateways: {len(revoked)}")
    print("-" * 65)
    for idx, item in enumerate(revoked, 1):
        print(f" {idx}. [{item['device_id']}] Revoked At: {item.get('revoked_at')}")
        print(f"    Reason: {item.get('reason', 'N/A')}")
    print("-" * 65)


def check_revocation(crl_path: Path, device_id: str) -> bool:
    crl = load_crl(crl_path)
    for entry in crl.get("revoked_devices", []):
        if entry["device_id"] == device_id:
            print(f"[REVOKED] Device '{device_id}' is listed! Reason: {entry.get('reason')}")
            return True
    print(f"[OK] Device '{device_id}' is NOT revoked.")
    return False


def main():
    parser = argparse.ArgumentParser(description="Manage KIWI Revocation List")
    parser.add_argument("--crl-file", type=Path, default=DEFAULT_CRL_FILE, help="Path to revocation_list.json")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # Subcommand: list
    subparsers.add_parser("list", help="List all revoked devices")

    # Subcommand: add
    add_parser = subparsers.add_parser("add", help="Add a device to revocation list")
    add_parser.add_argument("--device-id", required=True, help="Gateway device ID to revoke")
    add_parser.add_argument("--reason", default="Compromised credentials", help="Revocation reason")

    # Subcommand: remove
    rem_parser = subparsers.add_parser("remove", help="Remove a device from revocation list")
    rem_parser.add_argument("--device-id", required=True, help="Gateway device ID to un-revoke")

    # Subcommand: check
    check_parser = subparsers.add_parser("check", help="Check revocation status of a device")
    check_parser.add_argument("--device-id", required=True, help="Gateway device ID to inspect")

    args = parser.parse_args()

    if args.command == "list":
        list_revocations(args.crl_file)
    elif args.command == "add":
        add_revocation(args.crl_file, args.device_id, args.reason)
    elif args.command == "remove":
        remove_revocation(args.crl_file, args.device_id)
    elif args.command == "check":
        is_revoked = check_revocation(args.crl_file, args.device_id)
        sys.exit(1 if is_revoked else 0)


if __name__ == "__main__":
    main()
