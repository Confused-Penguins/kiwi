// KIWI Mobile Cryptographic & Threat Log Unit Test Suite
// Verifies 4-layer validation, Root CA signature verification, and bypass handling

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiwi_mobile/models/verification_models.dart';
import 'package:kiwi_mobile/services/crypto_service.dart';
import 'package:kiwi_mobile/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CryptoService cryptoService;

  setUp(() {
    cryptoService = CryptoService();
  });

  group('CryptoService Core Functionality', () {
    test('Nonce generation produces 32-byte (64 hex) string', () {
      final nonce1 = cryptoService.generateNonceHex();
      final nonce2 = cryptoService.generateNonceHex();

      expect(nonce1.length, equals(64));
      expect(nonce2.length, equals(64));
      expect(nonce1, isNot(equals(nonce2)));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(nonce1), isTrue);
    });

    test('Hex to bytes and bytes to hex are symmetrical', () {
      const hex = "deadbeef0123456789abcdef";
      final bytes = CryptoService.hexToBytes(hex);
      final reconstructedHex = CryptoService.bytesToHex(bytes);

      expect(reconstructedHex, equals(hex));
    });

    test('Layer 1: Verifies genuine Python-signed certificate against Root CA', () async {
      // Real certificate signed by generate_root_key.py & sign_gateway_cert.py
      final genuineCert = GatewayCertificate(
        deviceId: "KIWI-GW-TEST-001",
        publicKeyHex: "2bbcae6aefd00832de0bd7fb0d24fb7a79be0b9223550e4eb15fcb546fc22598",
        signatureHex:
            "6289eac3d2aea9933bd0ef434c4897bc5ea67544f37c617e66f24f9a4857ad9f7ff9f68c7bc74109c6bb825f40587afad8ba1d6f251db7427493abd6130e9e0d",
        issuedAt: 1726123456,
      );

      final isValid = await cryptoService.verifyCertificateRootCa(genuineCert);
      expect(isValid, isTrue, reason: "Genuine Root-signed cert must validate successfully");
    });

    test('Layer 1: Rejects tampered certificate attributes', () async {
      // Tampered Device ID
      final tamperedDevCert = GatewayCertificate(
        deviceId: "KIWI-SPOOFED-DEV",
        publicKeyHex: "2bbcae6aefd00832de0bd7fb0d24fb7a79be0b9223550e4eb15fcb546fc22598",
        signatureHex:
            "6289eac3d2aea9933bd0ef434c4897bc5ea67544f37c617e66f24f9a4857ad9f7ff9f68c7bc74109c6bb825f40587afad8ba1d6f251db7427493abd6130e9e0d",
        issuedAt: 1726123456,
      );
      expect(await cryptoService.verifyCertificateRootCa(tamperedDevCert), isFalse);

      // Tampered Public Key
      final tamperedKeyCert = GatewayCertificate(
        deviceId: "KIWI-GW-TEST-001",
        publicKeyHex: "00" * 32,
        signatureHex:
            "6289eac3d2aea9933bd0ef434c4897bc5ea67544f37c617e66f24f9a4857ad9f7ff9f68c7bc74109c6bb825f40587afad8ba1d6f251db7427493abd6130e9e0d",
        issuedAt: 1726123456,
      );
      expect(await cryptoService.verifyCertificateRootCa(tamperedKeyCert), isFalse);

      // Tampered Timestamp
      final tamperedTimeCert = GatewayCertificate(
        deviceId: "KIWI-GW-TEST-001",
        publicKeyHex: "2bbcae6aefd00832de0bd7fb0d24fb7a79be0b9223550e4eb15fcb546fc22598",
        signatureHex:
            "6289eac3d2aea9933bd0ef434c4897bc5ea67544f37c617e66f24f9a4857ad9f7ff9f68c7bc74109c6bb825f40587afad8ba1d6f251db7427493abd6130e9e0d",
        issuedAt: 1726199999,
      );
      expect(await cryptoService.verifyCertificateRootCa(tamperedTimeCert), isFalse);
    });

    test('Layer 3: Enforces Nonce Freshness and Timestamp Range', () {
      final cert = GatewayCertificate(
        deviceId: "KIWI-GW-TEST-001",
        publicKeyHex: "2bbcae6aefd00832de0bd7fb0d24fb7a79be0b9223550e4eb15fcb546fc22598",
        signatureHex: "00" * 64,
        issuedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60,
      );

      // Same nonce -> fresh
      expect(
        cryptoService.verifyFreshness(
          cert: cert,
          sentClientNonceHex: "aa" * 32,
          receivedClientNonceHex: "aa" * 32,
        ),
        isTrue,
      );

      // Nonce mismatch -> replay detected
      expect(
        cryptoService.verifyFreshness(
          cert: cert,
          sentClientNonceHex: "aa" * 32,
          receivedClientNonceHex: "bb" * 32,
        ),
        isFalse,
      );

      // Future clock skew > 300s -> rejected
      final futureCert = GatewayCertificate(
        deviceId: "KIWI-GW-TEST-001",
        publicKeyHex: cert.publicKeyHex,
        signatureHex: cert.signatureHex,
        issuedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      );
      expect(
        cryptoService.verifyFreshness(
          cert: futureCert,
          sentClientNonceHex: "aa" * 32,
          receivedClientNonceHex: "aa" * 32,
        ),
        isFalse,
      );
    });

    test('Layer 4: Correctly matches revoked device IDs', () {
      final revokedSet = {"KIWI-COMPROMISED-001", "KIWI-ROGUE-099"};

      expect(
        cryptoService.isDeviceRevoked(
          deviceId: "KIWI-COMPROMISED-001",
          revokedDeviceIds: revokedSet,
        ),
        isTrue,
      );

      expect(
        cryptoService.isDeviceRevoked(
          deviceId: "KIWI-GW-TEST-001",
          revokedDeviceIds: revokedSet,
        ),
        isFalse,
      );
    });
  });

  group('Threat Logging & Security Bypass', () {
    test('Threat incident is logged and retained even after bypass', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService(cryptoService, inMemorySecureStorage: {});
      await storage.init();

      final threat = ThreatLogEntry(
        id: "threat_test_01",
        ssid: "Rogue-AP-Zone",
        bssid: "11:22:33:44:55:66",
        timestamp: DateTime.now(),
        failedLayerName: "Layer 1: Root CA Signature",
        failureReason: "Untrusted Root Signature",
        bypassed: false,
      );

      await storage.logThreat(threat);
      var logs = storage.getThreatLogs();
      expect(logs.length, equals(1));
      expect(logs.first.bypassed, isFalse);

      // User performs bypass
      await storage.markThreatBypassed("threat_test_01");
      logs = storage.getThreatLogs();

      // Log must NOT be deleted, but marked as bypassed
      expect(logs.length, equals(1));
      expect(logs.first.bypassed, isTrue);
      expect(logs.first.ssid, equals("Rogue-AP-Zone"));
    });
  });
}
