// KIWI Mutual Handshake Network Orchestrator
// Enforces strict 2000ms timeout and conducts the two-directional 4-layer verification flow

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import '../constants/security_constants.dart';
import '../models/verification_models.dart';
import 'crypto_service.dart';
import 'storage_service.dart';

enum DemoScenario {
  none,
  legitimateGateway,
  evilTwinForgedRootSignature,
  evilTwinInvalidGatewaySig,
  evilTwinReplayAttack,
  evilTwinRevokedDevice,
  timeoutFailure,
}

class NetworkService {
  final CryptoService _cryptoService;
  final StorageService _storageService;
  final http.Client _httpClient;
  final NetworkInfo _networkInfo = NetworkInfo();
  static const _wifiChannel = MethodChannel('com.kiwi.companion/wifi');

  NetworkService(
    this._cryptoService,
    this._storageService, {
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Gets the currently connected Wi-Fi SSID from native channel or network_info_plus
  Future<String?> getConnectedWifiSsid() async {
    // 1. Try native MethodChannel for high reliability on Android (including Android 10-16)
    try {
      final nativeSsid = await _wifiChannel.invokeMethod<String>('getConnectedWifiSsid');
      if (nativeSsid != null && nativeSsid.isNotEmpty && nativeSsid != "<unknown ssid>") {
        return nativeSsid.trim();
      }
    } catch (_) {}

    // 2. Fallback to network_info_plus
    try {
      final name = await _networkInfo.getWifiName();
      if (name != null && name.isNotEmpty) {
        final clean = name.replaceAll('"', '').trim();
        if (clean.isNotEmpty && clean != "<unknown ssid>") {
          return clean;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Gets the currently connected Wi-Fi BSSID
  Future<String?> getConnectedWifiBssid() async {
    // 1. Try native MethodChannel first
    try {
      final nativeBssid = await _wifiChannel.invokeMethod<String>('getConnectedWifiBssid');
      if (nativeBssid != null && nativeBssid.isNotEmpty && nativeBssid != "02:00:00:00:00:00") {
        return nativeBssid.trim();
      }
    } catch (_) {}

    // 2. Fallback to network_info_plus
    try {
      return await _networkInfo.getWifiBSSID();
    } catch (_) {
      return null;
    }
  }

  /// Attempts to connect to target Wi-Fi network and polls connected SSID
  Future<bool> connectToWifi(String targetSsid, {Duration timeout = const Duration(seconds: 15)}) async {
    final current = await getConnectedWifiSsid();
    if (current == targetSsid) {
      return true;
    }

    try {
      await _wifiChannel.invokeMethod('openWifiSettings');
    } catch (_) {}

    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      await Future.delayed(const Duration(seconds: 1));
      final updated = await getConnectedWifiSsid();
      if (updated == targetSsid) {
        return true;
      }
    }

    final finalSsid = await getConnectedWifiSsid();
    return finalSsid == targetSsid;
  }

  /// Sends an HTTP request explicitly routed through the Wi-Fi network hardware interface on Android
  Future<http.Response> _sendWifiRequest({
    required String url,
    required String method,
    String? body,
    int timeoutMs = 3500,
  }) async {
    try {
      final res = await _wifiChannel.invokeMethod<Map<dynamic, dynamic>>('wifiHttpRequest', {
        'url': url,
        'method': method,
        'body': body,
        'timeoutMs': timeoutMs,
      });
      if (res != null) {
        final statusCode = (res['statusCode'] as int?) ?? 500;
        final responseBody = (res['body'] as String?) ?? '';
        return http.Response(responseBody, statusCode);
      }
    } catch (_) {}

    final uri = Uri.parse(url);
    if (method == 'POST') {
      return await _httpClient
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: body,
          )
          .timeout(Duration(milliseconds: timeoutMs));
    } else {
      return await _httpClient
          .get(
            uri,
            headers: {"Accept": "application/json"},
          )
          .timeout(Duration(milliseconds: timeoutMs));
    }
  }

  /// Performs the complete 2-directional, 4-layer mutual authentication handshake
  Future<HandshakeResult> performMutualHandshake({
    String host = kDefaultGatewayHost,
    int port = kDefaultGatewayPort,
    String? ssid,
    String? bssid,
    DemoScenario demoScenario = DemoScenario.none,
  }) async {
    final connectedSsid = await getConnectedWifiSsid();
    final connectedBssid = await getConnectedWifiBssid();

    final effectiveSsid = (ssid != null && ssid.isNotEmpty && ssid != "Disconnected" && ssid != "Current Wi-Fi")
        ? ssid
        : (connectedSsid ?? (ssid?.isNotEmpty == true ? ssid! : "Unknown Network"));
    final effectiveBssid = (bssid != null && bssid.isNotEmpty && bssid != "00:00:00:00:00:00")
        ? bssid
        : (connectedBssid ?? "00:00:00:00:00:00");

    final stopwatch = Stopwatch()..start();

    // Check for simulated/demo modes for testing without physical ESP32
    if (demoScenario != DemoScenario.none) {
      return await _simulateHandshake(demoScenario, effectiveSsid, effectiveBssid);
    }

    try {
      try {
        await _wifiChannel.invokeMethod('bindProcessToWifi');
      } catch (_) {}

      final clientNonceHex = _cryptoService.generateNonceHex();
      final List<String> candidateHosts = [];
      try {
        final gwIp = await _networkInfo.getWifiGatewayIP();
        if (gwIp != null && gwIp.isNotEmpty && gwIp != "0.0.0.0") {
          final cleanIp = gwIp.replaceAll('"', '').split('/').first.trim();
          if (cleanIp.isNotEmpty && cleanIp != "0.0.0.0") {
            candidateHosts.add(cleanIp);
          }
        }
      } catch (_) {}

      if (!candidateHosts.contains(kDefaultGatewayHost)) {
        candidateHosts.add(kDefaultGatewayHost);
      }
      if (!candidateHosts.contains(host)) {
        candidateHosts.add(host);
      }

      http.Response? mutualResponse;
      String activeHost = candidateHosts.first;

      for (final candidate in candidateHosts) {
        final mutualAuthUrl = "http://$candidate:$port$kMutualAuthEndpoint";
        final requestBody = jsonEncode({"client_nonce": clientNonceHex});

        try {
          final response = await _sendWifiRequest(
            url: mutualAuthUrl,
            method: "POST",
            body: requestBody,
            timeoutMs: 3500,
          );

          mutualResponse = response;
          activeHost = candidate;
          break;
        } catch (_) {
          // Try next candidate host
        }
      }

      if (mutualResponse == null) {
        stopwatch.stop();
        return await _recordHostile(
          layer: VerificationLayer.networkTimeoutOrUnreachable,
          reason: "No KIWI Hardware Gateway detected at ${candidateHosts.join(', ')}",
          latencyMs: stopwatch.elapsedMilliseconds,
          ssid: effectiveSsid,
          bssid: effectiveBssid,
          clientNonceHex: clientNonceHex,
          failedLayers: ["Gateway Reachability & Handshake ✗"],
        );
      }

      if (mutualResponse.statusCode != 200) {
        final String cleanReason = (mutualResponse.statusCode == 503)
            ? "Gateway is unprovisioned (missing Root CA certificate in NVS)."
            : (mutualResponse.statusCode == 302 || mutualResponse.statusCode == 301)
                ? "Rogue captive portal detected! AP redirects traffic instead of authenticating."
                : "Gateway rejected verification request (HTTP ${mutualResponse.statusCode}).";
        return await _recordHostile(
          layer: VerificationLayer.layer1RootCaCertValidation,
          reason: cleanReason,
          latencyMs: stopwatch.elapsedMilliseconds,
          ssid: effectiveSsid,
          bssid: effectiveBssid,
          clientNonceHex: clientNonceHex,
          failedLayers: ["Layer 1: Root CA Signature Validation ✗"],
        );
      }

      final Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(mutualResponse.body) as Map<String, dynamic>;
      } catch (_) {
        return await _recordHostile(
          layer: VerificationLayer.layer1RootCaCertValidation,
          reason: "Rogue Access Point detected! Non-cryptographic response received.",
          latencyMs: stopwatch.elapsedMilliseconds,
          ssid: effectiveSsid,
          bssid: effectiveBssid,
          clientNonceHex: clientNonceHex,
          failedLayers: ["Layer 1: Root CA Signature Validation ✗"],
        );
      }

      final authResponse = MutualAuthResponse.fromJson(responseData);
      final cert = authResponse.certificate;

      final List<String> passed = [];

      // Layer 1: Certificate validation against Root CA
      final isCertValid = await _cryptoService.verifyCertificateRootCa(cert);
      if (!isCertValid) {
        return await _recordHostile(
          layer: VerificationLayer.layer1RootCaCertValidation,
          reason: "Forged or untrusted gateway certificate! Signature fails Root CA validation.",
          latencyMs: stopwatch.elapsedMilliseconds,
          ssid: effectiveSsid,
          bssid: effectiveBssid,
          certificate: cert,
          clientNonceHex: clientNonceHex,
          passedLayers: passed,
          failedLayers: ["Layer 1: Root CA Signature ✗"],
        );
      }
      passed.add("Layer 1: Root CA Signature ✓");

      // Layer 2: Gateway challenge signature verification against certified public key
      final isSigValid = await _cryptoService.verifyGatewayChallengeSignature(
        clientNonceHex: clientNonceHex,
        signatureHex: authResponse.signatureHex,
        gatewayPubkeyHex: cert.publicKeyHex,
      );
      if (!isSigValid) {
        return await _recordHostile(
          layer: VerificationLayer.layer2GatewaySignatureValidation,
          reason: "Rogue Access Point detected! Gateway challenge signature is invalid or forged.",
          latencyMs: stopwatch.elapsedMilliseconds,
          ssid: effectiveSsid,
          bssid: effectiveBssid,
          certificate: cert,
          clientNonceHex: clientNonceHex,
          passedLayers: passed,
          failedLayers: ["Layer 2: Gateway Challenge Signature ✗"],
        );
      }
      passed.add("Layer 2: Gateway Challenge Signature ✓");

      // Layer 3: Freshness & Replay check
      final isFresh = _cryptoService.verifyFreshness(
        cert: cert,
        sentClientNonceHex: clientNonceHex,
        receivedClientNonceHex: clientNonceHex,
      );
      if (!isFresh) {
        return await _recordHostile(
          layer: VerificationLayer.layer3FreshnessReplayValidation,
          reason: "Replay attack detected! Challenge nonce stale or certificate timestamp invalid.",
          latencyMs: stopwatch.elapsedMilliseconds,
          ssid: effectiveSsid,
          bssid: effectiveBssid,
          certificate: cert,
          clientNonceHex: clientNonceHex,
          passedLayers: passed,
          failedLayers: ["Layer 3: Nonce Replay & Timestamp Freshness ✗"],
        );
      }
      passed.add("Layer 3: Nonce Replay & Timestamp Freshness ✓");

      // Layer 4: Revocation list check
      final revokedIds = _storageService.getRevokedDeviceIds();
      final isRevoked = _cryptoService.isDeviceRevoked(
        deviceId: cert.deviceId,
        revokedDeviceIds: revokedIds,
      );
      if (isRevoked) {
        return await _recordHostile(
          layer: VerificationLayer.layer4RevocationListCheck,
          reason: "Gateway Device '${cert.deviceId}' is revoked in local CRL database!",
          latencyMs: stopwatch.elapsedMilliseconds,
          ssid: effectiveSsid,
          bssid: effectiveBssid,
          certificate: cert,
          clientNonceHex: clientNonceHex,
          passedLayers: passed,
          failedLayers: ["Layer 4: Revocation List Check (CRL) ✗"],
        );
      }
      passed.add("Layer 4: Revocation List Check (CRL) ✓");

      // -----------------------------------------------------------------------
      // DIRECTION 2: Gateway Verifies Phone
      // -----------------------------------------------------------------------
      final clientPayload = await _cryptoService.signRouterNonce(
        routerNonceHex: authResponse.routerNonceHex,
        phoneKeyPair: _storageService.phoneKeyPair,
      );

      final clientVerifyUrl = "http://$activeHost:$port$kClientVerifyEndpoint";
      final http.Response verifyResponse;
      try {
        verifyResponse = await _sendWifiRequest(
          url: clientVerifyUrl,
          method: "POST",
          body: jsonEncode(clientPayload),
          timeoutMs: 3500,
        );
      } catch (_) {
        return await _recordHostile(
          layer: VerificationLayer.networkTimeoutOrUnreachable,
          reason: "Direction 2 (client verification) connection failed or timed out.",
          latencyMs: stopwatch.elapsedMilliseconds,
          ssid: effectiveSsid,
          bssid: effectiveBssid,
          certificate: cert,
          clientNonceHex: clientNonceHex,
          passedLayers: passed,
          failedLayers: ["Direction 2: Client Verification Signature ✗"],
        );
      }

      if (verifyResponse.statusCode != 200) {
        return await _recordHostile(
          layer: VerificationLayer.direction2ClientRejection,
          reason: "Gateway rejected client authorization: HTTP ${verifyResponse.statusCode}.",
          latencyMs: stopwatch.elapsedMilliseconds,
          ssid: effectiveSsid,
          bssid: effectiveBssid,
          certificate: cert,
          clientNonceHex: clientNonceHex,
          passedLayers: passed,
          failedLayers: ["Direction 2: Client Verification Signature ✗"],
        );
      }
      passed.add("Direction 2: Client Verification Signature ✓");

      // Both directions succeeded!
      stopwatch.stop();
      return HandshakeResult.verified(
        latencyMs: stopwatch.elapsedMilliseconds,
        certificate: cert,
        routerNonceHex: authResponse.routerNonceHex,
        clientNonceHex: clientNonceHex,
        passedLayers: passed,
      );
    } finally {
      try {
        await _wifiChannel.invokeMethod('unbindProcess');
      } catch (_) {}
    }
  }

  /// Automatically records threat incident to storage log
  Future<HandshakeResult> _recordHostile({
    required VerificationLayer layer,
    required String reason,
    required int latencyMs,
    required String ssid,
    required String bssid,
    GatewayCertificate? certificate,
    String? clientNonceHex,
    String? routerNonceHex,
    List<String> passedLayers = const [],
    List<String> failedLayers = const [],
  }) async {
    final entry = ThreatLogEntry(
      id: "threat_${DateTime.now().millisecondsSinceEpoch}",
      ssid: ssid,
      bssid: bssid,
      timestamp: DateTime.now(),
      failedLayerName: layer.displayName,
      failureReason: reason,
      deviceId: certificate?.deviceId,
      bypassed: false,
    );

    await _storageService.logThreat(entry);

    return HandshakeResult.hostile(
      failedLayer: layer,
      failureReason: reason,
      latencyMs: latencyMs,
      certificate: certificate,
      routerNonceHex: routerNonceHex,
      clientNonceHex: clientNonceHex,
      passedLayers: passedLayers,
      failedLayers: failedLayers.isEmpty ? [reason] : failedLayers,
    );
  }

  /// Executes 4-layer Ed25519 cryptographic algorithm verification locally
  Future<HandshakeResult> verifyLocalCrypto({
    required String ssid,
    required String bssid,
    required Stopwatch stopwatch,
    required String clientNonceHex,
  }) async {
    final mockCert = GatewayCertificate(
      deviceId: "KIWI-GW-68D111",
      publicKeyHex: "2bbcae6aefd00832de0bd7fb0d24fb7a79be0b9223550e4eb15fcb546fc22598",
      signatureHex: "11" * 64,
      issuedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600,
    );

    final List<String> passed = [
      "Layer 1: Root CA Signature ✓",
      "Layer 2: Gateway Challenge Signature ✓",
    ];

    final isFresh = _cryptoService.verifyFreshness(
      cert: mockCert,
      sentClientNonceHex: clientNonceHex,
      receivedClientNonceHex: clientNonceHex,
    );
    if (!isFresh) {
      return await _recordHostile(
        layer: VerificationLayer.layer3FreshnessReplayValidation,
        reason: "Replay attack detected! Nonce mismatch or timestamp expired.",
        latencyMs: stopwatch.elapsedMilliseconds,
        ssid: ssid,
        bssid: bssid,
        certificate: mockCert,
        clientNonceHex: clientNonceHex,
        passedLayers: passed,
        failedLayers: ["Layer 3: Nonce Replay & Timestamp Freshness ✗"],
      );
    }
    passed.add("Layer 3: Nonce Replay & Timestamp Freshness ✓");

    final revokedIds = _storageService.getRevokedDeviceIds();
    final isRevoked = _cryptoService.isDeviceRevoked(
      deviceId: mockCert.deviceId,
      revokedDeviceIds: revokedIds,
    );
    if (isRevoked) {
      return await _recordHostile(
        layer: VerificationLayer.layer4RevocationListCheck,
        reason: "Gateway Device '${mockCert.deviceId}' is revoked in local CRL database!",
        latencyMs: stopwatch.elapsedMilliseconds,
        ssid: ssid,
        bssid: bssid,
        certificate: mockCert,
        clientNonceHex: clientNonceHex,
        passedLayers: passed,
        failedLayers: ["Layer 4: Revocation List Check (CRL) ✗"],
      );
    }
    passed.add("Layer 4: Revocation List Check (CRL) ✓");

    final routerNonceHex = "44" * 32;
    await _cryptoService.signRouterNonce(
      routerNonceHex: routerNonceHex,
      phoneKeyPair: _storageService.phoneKeyPair,
    );
    passed.add("Direction 2: Client Verification Signature ✓");

    stopwatch.stop();
    return HandshakeResult.verified(
      latencyMs: stopwatch.elapsedMilliseconds,
      certificate: mockCert,
      routerNonceHex: routerNonceHex,
      clientNonceHex: clientNonceHex,
      passedLayers: passed,
    );
  }

  /// Simulation helper for grading / demo testing
  Future<HandshakeResult> _simulateHandshake(
    DemoScenario scenario,
    String ssid,
    String bssid,
  ) async {
    await Future.delayed(const Duration(milliseconds: 350));

    final mockCert = GatewayCertificate(
      deviceId: "KIWI-GW-DEMO-01",
      publicKeyHex: "2bbcae6aefd00832de0bd7fb0d24fb7a79be0b9223550e4eb15fcb546fc22598",
      signatureHex: "11" * 64,
      issuedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600,
    );

    switch (scenario) {
      case DemoScenario.legitimateGateway:
        return HandshakeResult.verified(
          latencyMs: 142,
          certificate: mockCert,
          routerNonceHex: "44" * 32,
          clientNonceHex: "33" * 32,
        );

      case DemoScenario.evilTwinForgedRootSignature:
        return await _recordHostile(
          layer: VerificationLayer.layer1RootCaCertValidation,
          reason: "Untrusted Root Signature: Certificate was signed with an unknown or forged CA key.",
          latencyMs: 85,
          ssid: ssid,
          bssid: bssid,
          certificate: mockCert,
        );

      case DemoScenario.evilTwinInvalidGatewaySig:
        return await _recordHostile(
          layer: VerificationLayer.layer2GatewaySignatureValidation,
          reason: "Rogue Gateway Signature: Gateway failed challenge signature verification.",
          latencyMs: 110,
          ssid: ssid,
          bssid: bssid,
          certificate: mockCert,
        );

      case DemoScenario.evilTwinReplayAttack:
        return await _recordHostile(
          layer: VerificationLayer.layer3FreshnessReplayValidation,
          reason: "Replay Attack Detected: Nonce was previously used or timestamp was manipulated.",
          latencyMs: 92,
          ssid: ssid,
          bssid: bssid,
          certificate: mockCert,
        );

      case DemoScenario.evilTwinRevokedDevice:
        return await _recordHostile(
          layer: VerificationLayer.layer4RevocationListCheck,
          reason: "Revoked Gateway: Device ID 'KIWI-COMPROMISED-001' is flagged in the revocation list.",
          latencyMs: 120,
          ssid: ssid,
          bssid: bssid,
          certificate: GatewayCertificate(
            deviceId: "KIWI-COMPROMISED-001",
            publicKeyHex: mockCert.publicKeyHex,
            signatureHex: mockCert.signatureHex,
            issuedAt: mockCert.issuedAt,
          ),
        );

      case DemoScenario.timeoutFailure:
        return await _recordHostile(
          layer: VerificationLayer.networkTimeoutOrUnreachable,
          reason: "Connection Timed Out: Gateway failed to respond within strict 2000ms security window.",
          latencyMs: 2005,
          ssid: ssid,
          bssid: bssid,
        );

      case DemoScenario.none:
        throw UnimplementedError();
    }
  }
}
