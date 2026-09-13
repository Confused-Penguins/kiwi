// KIWI Secure Storage & Threat Audit Logging Engine
// Uses flutter_secure_storage (Android Keystore / iOS Keychain) for private keys
// Uses SharedPreferences for threat logs and cached CRL

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/security_constants.dart';
import '../models/verification_models.dart';
import 'crypto_service.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage;
  final Map<String, String>? inMemorySecureStorage;
  final CryptoService _cryptoService;
  late SharedPreferences _prefs;

  SimpleKeyPair? _cachedPhoneKeyPair;
  String? _cachedPhonePubKeyHex;

  StorageService(
    this._cryptoService, {
    this.inMemorySecureStorage,
  }) : _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  Future<String?> _readSecure(String key) async {
    final mem = inMemorySecureStorage;
    if (mem != null) {
      return mem[key];
    }
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSecure(String key, String value) async {
    final mem = inMemorySecureStorage;
    if (mem != null) {
      mem[key] = value;
      return;
    }
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {}
  }

  /// Initializes secure storage and ensures phone's hardware-backed keypair exists
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // 1. Check or generate phone's Ed25519 keypair in secure storage
    final existingSeedHex = await _readSecure(kSecurePhonePrivKeyKey);

    if (existingSeedHex != null && existingSeedHex.length == 64) {
      try {
        final seedBytes = CryptoService.hexToBytes(existingSeedHex);
        _cachedPhoneKeyPair = await _cryptoService.keyPairFromSeed(seedBytes);
        final pub = await _cachedPhoneKeyPair!.extractPublicKey();
        _cachedPhonePubKeyHex = CryptoService.bytesToHex(pub.bytes);
      } catch (_) {
        await _generateAndSaveNewPhoneKey();
      }
    } else {
      await _generateAndSaveNewPhoneKey();
    }

    // 2. Initialize starter CRL cache if empty
    if (!_prefs.containsKey(kCachedCrlPrefsKey)) {
      final starterCrl = [
        "KIWI-COMPROMISED-001",
        "KIWI-ROGUE-099",
      ];
      await _prefs.setStringList(kCachedCrlPrefsKey, starterCrl);
      await _prefs.setInt(kCrlLastSyncPrefsKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
    }
  }

  Future<void> _generateAndSaveNewPhoneKey() async {
    final keyPair = await _cryptoService.generatePhoneKeyPair();
    final seedBytes = await keyPair.extractPrivateKeyBytes();
    final pubKey = await keyPair.extractPublicKey();

    final seedHex = CryptoService.bytesToHex(seedBytes);
    final pubHex = CryptoService.bytesToHex(pubKey.bytes);

    // CRITICAL: Store private key in hardware-backed secure storage
    await _writeSecure(kSecurePhonePrivKeyKey, seedHex);
    await _writeSecure(kSecurePhonePubKeyKey, pubHex);

    _cachedPhoneKeyPair = keyPair;
    _cachedPhonePubKeyHex = pubHex;
  }

  SimpleKeyPair get phoneKeyPair {
    if (_cachedPhoneKeyPair == null) {
      throw StateError("StorageService.init() must be called before accessing phoneKeyPair");
    }
    return _cachedPhoneKeyPair!;
  }

  String get phonePublicKeyHex {
    return _cachedPhonePubKeyHex ?? "UNKNOWN";
  }

  // --- Threat Logging (Audit Trail) ---

  /// Appends a new security threat incident to local audit log.
  /// Persisted regardless of whether user subsequently bypasses the warning.
  Future<void> logThreat(ThreatLogEntry entry) async {
    final rawLogs = _prefs.getStringList(kThreatLogPrefsKey) ?? [];
    rawLogs.insert(0, jsonEncode(entry.toJson()));
    // Retain up to 200 forensic log entries
    if (rawLogs.length > 200) {
      rawLogs.removeRange(200, rawLogs.length);
    }
    await _prefs.setStringList(kThreatLogPrefsKey, rawLogs);
  }

  /// Records a user-submitted security threat incident report with location
  Future<ThreatLogEntry> reportIncident({
    required String ssid,
    required String bssid,
    required String reason,
    String? location,
    String? deviceId,
  }) async {
    final entry = ThreatLogEntry(
      id: "REP-${DateTime.now().millisecondsSinceEpoch}",
      ssid: ssid,
      bssid: bssid,
      timestamp: DateTime.now(),
      failedLayerName: "User Security Report",
      failureReason: reason,
      deviceId: deviceId,
      bypassed: false,
      location: location,
      isReported: true,
    );
    await logThreat(entry);
    return entry;
  }

  List<ThreatLogEntry> getThreatLogs() {
    final rawLogs = _prefs.getStringList(kThreatLogPrefsKey) ?? [];
    final List<ThreatLogEntry> results = [];
    for (final raw in rawLogs) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        results.add(ThreatLogEntry.fromJson(decoded));
      } catch (_) {}
    }
    return results;
  }

  Future<void> markThreatBypassed(String threatId) async {
    final rawLogs = _prefs.getStringList(kThreatLogPrefsKey) ?? [];
    final List<String> updated = [];
    for (final raw in rawLogs) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        if (decoded['id'] == threatId) {
          decoded['bypassed'] = true;
        }
        updated.add(jsonEncode(decoded));
      } catch (_) {
        updated.add(raw);
      }
    }
    await _prefs.setStringList(kThreatLogPrefsKey, updated);
  }

  Future<void> clearThreatLogs() async {
    await _prefs.remove(kThreatLogPrefsKey);
  }

  // --- Verified Networks Cache ---
  static const String _kVerifiedNetworksKey = "kiwi_verified_networks_cache";

  Future<void> setNetworkVerified(String ssid, bool isVerified) async {
    final list = _prefs.getStringList(_kVerifiedNetworksKey) ?? [];
    final set = list.map((e) => e.toLowerCase()).toSet();
    if (isVerified) {
      set.add(ssid.toLowerCase());
    } else {
      set.remove(ssid.toLowerCase());
    }
    await _prefs.setStringList(_kVerifiedNetworksKey, set.toList());
  }

  bool isNetworkVerified(String? ssid) {
    if (ssid == null || ssid.isEmpty || ssid == "Disconnected") return false;
    final list = _prefs.getStringList(_kVerifiedNetworksKey) ?? [];
    return list.any((e) => e.toLowerCase() == ssid.toLowerCase());
  }

  // --- Revocation List (CRL) Management ---

  Set<String> getRevokedDeviceIds() {
    final list = _prefs.getStringList(kCachedCrlPrefsKey) ?? [];
    return list.map((e) => e.toUpperCase()).toSet();
  }

  Future<void> updateRevocationList(List<String> deviceIds) async {
    await _prefs.setStringList(kCachedCrlPrefsKey, deviceIds);
    await _prefs.setInt(kCrlLastSyncPrefsKey, DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  int get crlLastSyncTimestamp {
    return _prefs.getInt(kCrlLastSyncPrefsKey) ?? 0;
  }

  bool isCrlStale() {
    final lastSync = crlLastSyncTimestamp;
    if (lastSync == 0) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now - lastSync) > kCrlStalenessThresholdSeconds;
  }
}
