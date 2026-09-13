// KIWI Mobile Cryptographic Engine
// RFC 8032 Ed25519 Mutual Authentication Implementation

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import '../constants/security_constants.dart';
import '../models/verification_models.dart';

class CryptoService {
  final Ed25519 _algorithm = Ed25519();
  final Random _secureRandom = Random.secure();

  /// Converts byte array to lowercase hexadecimal string
  static String bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Converts hexadecimal string to Uint8List
  static Uint8List hexToBytes(String hex) {
    final clean = hex.replaceAll(' ', '').toLowerCase();
    if (clean.length % 2 != 0) {
      throw const FormatException("Hex string must have an even length");
    }
    final result = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < clean.length; i += 2) {
      result[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Generates a fresh 32-byte cryptographically secure random nonce
  String generateNonceHex() {
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytesToHex(bytes);
  }

  /// Generates a fresh Ed25519 keypair for the mobile application
  Future<SimpleKeyPair> generatePhoneKeyPair() async {
    return await _algorithm.newKeyPair();
  }

  /// Restores a keypair from raw 32-byte private seed
  Future<SimpleKeyPair> keyPairFromSeed(List<int> seedBytes) async {
    return await _algorithm.newKeyPairFromSeed(seedBytes);
  }

  /// Layer 1: Verify Gateway Certificate against Hardcoded KIWI Root Public Key
  Future<bool> verifyCertificateRootCa(GatewayCertificate cert) async {
    try {
      final rootPubBytes = hexToBytes(kKiwiRootPublicKeyHex);
      final rootPublicKey = SimplePublicKey(rootPubBytes, type: KeyPairType.ed25519);

      // Canonical payload: "KIWI-CERT:v1:<device_id>:<public_key_hex>:<issued_at>"
      final canonicalStr =
          "$kCertCanonicalPrefix${cert.deviceId}:${cert.publicKeyHex.toLowerCase()}:${cert.issuedAt}";
      final payloadBytes = utf8.encode(canonicalStr);

      final sigBytes = hexToBytes(cert.signatureHex);
      final signature = Signature(sigBytes, publicKey: rootPublicKey);

      return await _algorithm.verify(payloadBytes, signature: signature);
    } catch (_) {
      return false;
    }
  }

  /// Layer 2: Verify Gateway Challenge Response Signature against Certified Public Key
  Future<bool> verifyGatewayChallengeSignature({
    required String clientNonceHex,
    required String signatureHex,
    required String gatewayPubkeyHex,
  }) async {
    try {
      final gwPubBytes = hexToBytes(gatewayPubkeyHex);
      final gwPublicKey = SimplePublicKey(gwPubBytes, type: KeyPairType.ed25519);

      // Canonical payload: "KIWI-AUTH:v1:<client_nonce_hex>"
      final canonicalStr = "$kAuthChallengePrefix${clientNonceHex.toLowerCase()}";
      final payloadBytes = utf8.encode(canonicalStr);

      final sigBytes = hexToBytes(signatureHex);
      final signature = Signature(sigBytes, publicKey: gwPublicKey);

      return await _algorithm.verify(payloadBytes, signature: signature);
    } catch (_) {
      return false;
    }
  }

  /// Layer 3: Nonce and Timestamp Freshness Verification
  bool verifyFreshness({
    required GatewayCertificate cert,
    required String sentClientNonceHex,
    required String receivedClientNonceHex,
  }) {
    // Check nonce match (prevent cross-session replay)
    if (sentClientNonceHex.toLowerCase() != receivedClientNonceHex.toLowerCase()) {
      return false;
    }

    // Check certificate issuance time is reasonable (not in far future, not prehistoric)
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Allow up to 300 seconds future clock skew
    if (cert.issuedAt > (nowEpoch + 300)) {
      return false;
    }
    // Must be issued after KIWI project epoch (2024-01-01 = 1704067200)
    if (cert.issuedAt < 1704067200) {
      return false;
    }

    return true;
  }

  /// Layer 4: Check Revocation List
  bool isDeviceRevoked({
    required String deviceId,
    required Set<String> revokedDeviceIds,
  }) {
    return revokedDeviceIds.contains(deviceId.toUpperCase()) ||
        revokedDeviceIds.contains(deviceId);
  }

  /// Direction 2: Sign router nonce with mobile phone's private key
  Future<Map<String, String>> signRouterNonce({
    required String routerNonceHex,
    required SimpleKeyPair phoneKeyPair,
  }) async {
    // Canonical payload: "KIWI-CLIENT:v1:<router_nonce_hex>"
    final canonicalStr = "$kClientVerifyPrefix${routerNonceHex.toLowerCase()}";
    final payloadBytes = utf8.encode(canonicalStr);

    final signature = await _algorithm.sign(payloadBytes, keyPair: phoneKeyPair);
    final pubKey = await phoneKeyPair.extractPublicKey();

    return {
      "router_nonce": routerNonceHex.toLowerCase(),
      "signature": bytesToHex(signature.bytes),
      "phone_public_key": bytesToHex(pubKey.bytes),
    };
  }
}
