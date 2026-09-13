#!/usr/bin/env python3
"""
KIWI Provisioning End-to-End Automated Test Suite
Verifies:
1. Root key generation and vault security.
2. Mock gateway key generation.
3. Certificate signing by Root CA.
4. Cryptographic validation of certificate against Root CA public key.
5. Detection of tampered certificates (tampered key, device ID, timestamp).
6. Revocation list enforcement (Layer 4).
"""

import json
import os
import shutil
import tempfile
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.hazmat.primitives import serialization

# Import provisioning modules
import generate_root_key
import sign_gateway_cert
import verify_cert
import manage_revocation


def run_tests():
    print("=================================================================")
    print(" RUNNING KIWI PROVISIONING SYSTEM END-TO-END VERIFICATION")
    print("=================================================================")

    temp_dir = Path(tempfile.mkdtemp(prefix="kiwi_test_"))
    try:
        vault_dir = temp_dir / "vault"
        vault_file = vault_dir / "root_private_key.json"
        pubkey_hex_file = vault_dir / "root_public_key.hex"
        crl_file = temp_dir / "test_revocation_list.json"
        cert_file = temp_dir / "test_gateway_cert.json"

        # Override module paths
        generate_root_key.VAULT_DIR = vault_dir
        generate_root_key.PRIVATE_KEY_FILE = vault_file
        generate_root_key.PUBLIC_KEY_HEX_FILE = pubkey_hex_file
        generate_root_key.PUBLIC_KEY_PEM_FILE = vault_dir / "root_public_key.pem"

        # Test 1: Root Key Generation
        print("\n[TEST 1] Generating Root CA Keypair...")
        generate_root_key.generate_root_keypair(force=True)
        assert vault_file.exists(), "Vault file was not created!"
        assert pubkey_hex_file.exists(), "Public key hex file was not created!"

        with open(vault_file, "r") as f:
            vault_data = json.load(f)
        root_priv_hex = vault_data["private_key_hex"]
        root_pub_hex = vault_data["public_key_hex"]
        assert len(root_priv_hex) == 64, "Root private key must be 32 bytes (64 hex chars)"
        assert len(root_pub_hex) == 64, "Root public key must be 32 bytes (64 hex chars)"
        print("  ✓ Root keypair generated and validated.")

        # Test 2: Mock Gateway Key Generation
        print("\n[TEST 2] Generating Mock ESP32 Gateway Ed25519 Keypair...")
        mock_gw_priv = ed25519.Ed25519PrivateKey.generate()
        mock_gw_pub = mock_gw_priv.public_key()
        mock_gw_pub_bytes = mock_gw_pub.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw
        )
        mock_gw_pub_hex = mock_gw_pub_bytes.hex()
        mock_device_id = "KIWI-ESP32-TEST-001"
        print(f"  Mock Gateway Device ID : {mock_device_id}")
        print(f"  Mock Gateway Public Key: {mock_gw_pub_hex}")
        print("  ✓ Mock gateway key generated.")

        # Test 3: Sign Gateway Certificate
        print("\n[TEST 3] Signing Gateway Public Key with Root CA...")
        cert = sign_gateway_cert.sign_gateway(
            device_id=mock_device_id,
            gateway_pubkey_hex=mock_gw_pub_hex,
            vault_path=vault_file,
            issued_at=1726123456,
            output_file=cert_file
        )
        assert cert_file.exists(), "Certificate file was not written!"
        assert cert["device_id"] == mock_device_id
        assert cert["public_key"] == mock_gw_pub_hex
        assert len(cert["signature"]) == 128, "Signature must be 64 bytes (128 hex chars)"
        print("  ✓ Gateway certificate signed successfully.")

        # Test 4: Verify Genuine Certificate
        print("\n[TEST 4] Verifying Genuine Gateway Certificate...")
        valid, msg = verify_cert.verify_certificate(cert, root_pub_hex, crl_file)
        print(f"  Result: {msg}")
        assert valid is True, f"Legitimate certificate failed validation: {msg}"
        print("  ✓ Legitimate certificate verified.")

        # Test 5: Detect Tampering
        print("\n[TEST 5] Verifying Tamper Resistance...")
        # 5a: Altered public key
        tampered_cert_key = dict(cert)
        tampered_cert_key["public_key"] = "00" * 32
        valid, msg = verify_cert.verify_certificate(tampered_cert_key, root_pub_hex, crl_file)
        assert valid is False, "Tampered public key was NOT detected!"
        print("  ✓ Tampered public key successfully rejected.")

        # 5b: Altered device ID
        tampered_cert_dev = dict(cert)
        tampered_cert_dev["device_id"] = "KIWI-SPOOFED-DEV"
        valid, msg = verify_cert.verify_certificate(tampered_cert_dev, root_pub_hex, crl_file)
        assert valid is False, "Tampered device ID was NOT detected!"
        print("  ✓ Tampered device ID successfully rejected.")

        # 5c: Altered timestamp
        tampered_cert_time = dict(cert)
        tampered_cert_time["issued_at"] = 9999999999
        valid, msg = verify_cert.verify_certificate(tampered_cert_time, root_pub_hex, crl_file)
        assert valid is False, "Tampered timestamp was NOT detected!"
        print("  ✓ Tampered timestamp successfully rejected.")

        # Test 6: Revocation List Enforcement (Layer 4)
        print("\n[TEST 6] Testing Revocation List Enforcement...")
        # Add to CRL
        manage_revocation.add_revocation(crl_file, mock_device_id, "Test revocation")
        valid, msg = verify_cert.verify_certificate(cert, root_pub_hex, crl_file)
        assert valid is False, "Revoked gateway was accepted!"
        assert "REVOKED" in msg, f"Expected revocation notice in message: {msg}"
        print("  ✓ Revoked gateway successfully blocked.")

        # Remove from CRL
        manage_revocation.remove_revocation(crl_file, mock_device_id)
        valid, msg = verify_cert.verify_certificate(cert, root_pub_hex, crl_file)
        assert valid is True, "Un-revoked gateway was not restored!"
        print("  ✓ Un-revoking restored valid status.")

        print("\n=================================================================")
        print(" [✓] ALL 6 PROVISIONING INTEGRATION TESTS PASSED WITH 100% SUCCESS")
        print("=================================================================")
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    run_tests()
