// KIWI Verification & Protocol Models
// 4-Layer Mutual Authentication System

enum VerificationLayer {
  layer1RootCaCertValidation,
  layer2GatewaySignatureValidation,
  layer3FreshnessReplayValidation,
  layer4RevocationListCheck,
  networkTimeoutOrUnreachable,
  direction2ClientRejection,
}

extension VerificationLayerExtension on VerificationLayer {
  String get displayName {
    switch (this) {
      case VerificationLayer.layer1RootCaCertValidation:
        return "Layer 1: Root CA Signature";
      case VerificationLayer.layer2GatewaySignatureValidation:
        return "Layer 2: Gateway Challenge Signature";
      case VerificationLayer.layer3FreshnessReplayValidation:
        return "Layer 3: Nonce Replay & Freshness";
      case VerificationLayer.layer4RevocationListCheck:
        return "Layer 4: Revocation List Check";
      case VerificationLayer.networkTimeoutOrUnreachable:
        return "Gateway Unreachable";
      case VerificationLayer.direction2ClientRejection:
        return "Direction 2: Client Verification";
    }
  }

  String get description {
    switch (this) {
      case VerificationLayer.layer1RootCaCertValidation:
        return "Certificate signature fails validation against hardcoded KIWI Root CA public key.";
      case VerificationLayer.layer2GatewaySignatureValidation:
        return "Gateway response signature fails validation against certified gateway public key.";
      case VerificationLayer.layer3FreshnessReplayValidation:
        return "Challenge nonce mismatch or certificate issuance timestamp expired/invalid.";
      case VerificationLayer.layer4RevocationListCheck:
        return "Gateway Device ID matches a revoked entry in the Certificate Revocation List (CRL).";
      case VerificationLayer.networkTimeoutOrUnreachable:
        return "Gateway connection timed out or is unreachable.";
      case VerificationLayer.direction2ClientRejection:
        return "Gateway rejected phone client authorization challenge (HTTP 403).";
    }
  }
}

class GatewayCertificate {
  final String deviceId;
  final String publicKeyHex;
  final String signatureHex;
  final int issuedAt;

  GatewayCertificate({
    required this.deviceId,
    required this.publicKeyHex,
    required this.signatureHex,
    required this.issuedAt,
  });

  factory GatewayCertificate.fromJson(Map<String, dynamic> json) {
    return GatewayCertificate(
      deviceId: json['device_id'] as String? ?? 'UNKNOWN',
      publicKeyHex: (json['public_key'] as String? ?? '').toLowerCase(),
      signatureHex: (json['signature'] as String? ?? '').toLowerCase(),
      issuedAt: (json['issued_at'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'public_key': publicKeyHex,
        'signature': signatureHex,
        'issued_at': issuedAt,
      };
}

class MutualAuthResponse {
  final String signatureHex;
  final String routerNonceHex;
  final GatewayCertificate certificate;

  MutualAuthResponse({
    required this.signatureHex,
    required this.routerNonceHex,
    required this.certificate,
  });

  factory MutualAuthResponse.fromJson(Map<String, dynamic> json) {
    return MutualAuthResponse(
      signatureHex: (json['signature'] as String? ?? '').toLowerCase(),
      routerNonceHex: (json['router_nonce'] as String? ?? '').toLowerCase(),
      certificate: GatewayCertificate.fromJson(
        json['certificate'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'signature': signatureHex,
        'router_nonce': routerNonceHex,
        'certificate': certificate.toJson(),
      };
}

class HandshakeResult {
  final bool isVerified;
  final bool isHostile;
  final VerificationLayer? failedLayer;
  final String? failureReason;
  final int latencyMs;
  final GatewayCertificate? certificate;
  final String? routerNonceHex;
  final String? clientNonceHex;
  final DateTime timestamp;
  final List<String> passedLayers;
  final List<String> failedLayers;
  bool bypassed;

  HandshakeResult({
    required this.isVerified,
    required this.isHostile,
    this.failedLayer,
    this.failureReason,
    required this.latencyMs,
    this.certificate,
    this.routerNonceHex,
    this.clientNonceHex,
    DateTime? timestamp,
    this.passedLayers = const [],
    this.failedLayers = const [],
    this.bypassed = false,
  }) : timestamp = timestamp ?? DateTime.now();

  factory HandshakeResult.verified({
    required int latencyMs,
    required GatewayCertificate certificate,
    required String routerNonceHex,
    required String clientNonceHex,
    List<String> passedLayers = const [],
  }) {
    return HandshakeResult(
      isVerified: true,
      isHostile: false,
      latencyMs: latencyMs,
      certificate: certificate,
      routerNonceHex: routerNonceHex,
      clientNonceHex: clientNonceHex,
      passedLayers: passedLayers,
    );
  }

  factory HandshakeResult.hostile({
    required VerificationLayer failedLayer,
    required String failureReason,
    required int latencyMs,
    GatewayCertificate? certificate,
    String? routerNonceHex,
    String? clientNonceHex,
    List<String> passedLayers = const [],
    List<String> failedLayers = const [],
  }) {
    return HandshakeResult(
      isVerified: false,
      isHostile: true,
      failedLayer: failedLayer,
      failureReason: failureReason,
      latencyMs: latencyMs,
      certificate: certificate,
      routerNonceHex: routerNonceHex,
      clientNonceHex: clientNonceHex,
      passedLayers: passedLayers,
      failedLayers: failedLayers,
    );
  }
}

class ThreatLogEntry {
  final String id;
  final String ssid;
  final String bssid;
  final DateTime timestamp;
  final String failedLayerName;
  final String failureReason;
  final String? deviceId;
  final bool bypassed;
  final String? location;
  final bool isReported;

  ThreatLogEntry({
    required this.id,
    required this.ssid,
    required this.bssid,
    required this.timestamp,
    required this.failedLayerName,
    required this.failureReason,
    this.deviceId,
    required this.bypassed,
    this.location,
    this.isReported = false,
  });

  factory ThreatLogEntry.fromJson(Map<String, dynamic> json) {
    return ThreatLogEntry(
      id: json['id'] as String? ?? '',
      ssid: json['ssid'] as String? ?? 'Unknown AP',
      bssid: json['bssid'] as String? ?? '00:00:00:00:00:00',
      timestamp: DateTime.parse(
          json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      failedLayerName: json['failed_layer'] as String? ?? 'Security Failure',
      failureReason: json['failure_reason'] as String? ?? 'Unknown Threat',
      deviceId: json['device_id'] as String?,
      bypassed: json['bypassed'] as bool? ?? false,
      location: json['location'] as String?,
      isReported: json['is_reported'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ssid': ssid,
        'bssid': bssid,
        'timestamp': timestamp.toIso8601String(),
        'failed_layer': failedLayerName,
        'failure_reason': failureReason,
        'device_id': deviceId,
        'bypassed': bypassed,
        'location': location,
        'is_reported': isReported,
      };
}

class ApScanItem {
  final String ssid;
  final String bssid;
  final int rssi;
  final bool isOpen;
  final bool isTargetKiwiZone;

  ApScanItem({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.isOpen,
    required this.isTargetKiwiZone,
  });
}
