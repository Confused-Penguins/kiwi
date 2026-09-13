import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/verification_models.dart';
import '../services/crypto_service.dart';
import '../services/network_service.dart';
import '../services/storage_service.dart';
import 'status_screen.dart';

class ScannerScreen extends StatefulWidget {
  final NetworkService networkService;

  const ScannerScreen({super.key, required this.networkService});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with TickerProviderStateMixin {
  bool _isScanning = false;
  final TextEditingController _searchController = TextEditingController();
  List<ApScanItem> _networks = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    await Permission.location.request();
    await Permission.nearbyWifiDevices.request();
    await _loadDiscoveredNetworks();
  }

  bool _isOpenAp(WiFiAccessPoint ap) {
    final cap = ap.capabilities.toUpperCase();
    if (cap.contains("WPA") ||
        cap.contains("WEP") ||
        cap.contains("PSK") ||
        cap.contains("SAE") ||
        cap.contains("EAP") ||
        cap.contains("802_1X") ||
        cap.contains("OWE")) {
      return false;
    }
    return true;
  }

  Future<void> _loadDiscoveredNetworks() async {
    if (!mounted) return;
    setState(() => _isScanning = true);

    final List<ApScanItem> items = [];
    final Set<String> seenSsids = {};

    // 1. Get currently connected Wi-Fi (if any)
    final activeSsid = await widget.networkService.getConnectedWifiSsid();
    final activeBssid = await widget.networkService.getConnectedWifiBssid() ?? "";

    if (activeSsid != null && activeSsid.isNotEmpty) {
      items.add(
        ApScanItem(
          ssid: activeSsid,
          bssid: activeBssid.isNotEmpty ? activeBssid : "00:00:00:00:00:00",
          rssi: -45,
          isOpen: false,
          isTargetKiwiZone: true,
        ),
      );
      seenSsids.add(activeSsid.toLowerCase());
    }

    // 2. Perform real hardware Wi-Fi scanning with WiFiScan
    try {
      final canStart = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (canStart == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
      }
    } catch (_) {}

    try {
      final canGet = await WiFiScan.instance.canGetScannedResults(askPermissions: true);
      if (canGet == CanGetScannedResults.yes) {
        final accessPoints = await WiFiScan.instance.getScannedResults();

        // Sort by signal strength (strongest first)
        final sorted = List<WiFiAccessPoint>.from(accessPoints)
          ..sort((a, b) => b.level.compareTo(a.level));

        for (final ap in sorted) {
          final rawSsid = ap.ssid.trim();
          if (rawSsid.isEmpty || rawSsid == "<unknown ssid>") continue;

          final isOpen = _isOpenAp(ap);

          // Show all detected open Wi-Fi networks in the user's area
          if (isOpen) {
            if (!seenSsids.contains(rawSsid.toLowerCase())) {
              seenSsids.add(rawSsid.toLowerCase());
              items.add(
                ApScanItem(
                  ssid: rawSsid,
                  bssid: ap.bssid,
                  rssi: ap.level,
                  isOpen: true,
                  isTargetKiwiZone: false,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _networks = items;
        _isScanning = false;
      });
    }
  }

  Future<void> _verifyNetwork(ApScanItem network) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusScreen(
          networkService: widget.networkService,
          targetSsid: network.ssid,
          targetBssid: network.bssid,
        ),
      ),
    );
    if (res is HandshakeResult && mounted) {
      final storage = StorageService(CryptoService());
      await storage.init();
      await storage.setNetworkVerified(network.ssid, res.isVerified);
      if (mounted) {
        Navigator.pop(context, res);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _networks.where((n) {
      if (_searchQuery.isEmpty) return true;
      return n.ssid.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFDCE0E5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation & Page Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    "Nearby Networks",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                      color: Color(0xFF111827),
                    ),
                  ),
                  InkWell(
                    onTap: _loadDiscoveredNetworks,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isScanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111827)),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                size: 22,
                                color: Color(0xFF111827),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Wi-Fi Networks Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                  decoration: const InputDecoration(
                    hintText: "Search Wi-Fi Networks...",
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Caption
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
              child: Text(
                "Available networks detected nearby",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ),

            // Network Cards List
            Expanded(
              child: _isScanning && filtered.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF111827)),
                          SizedBox(height: 16),
                          Text(
                            "Scanning for open Wi-Fi networks...",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.wifi_off_rounded,
                                    size: 32,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "No Open Networks Detected",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "Make sure Location & Wi-Fi are enabled, then tap the refresh button above to scan nearby open networks.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final net = filtered[index];
                            final isPrimary = index == 0;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.wifi_rounded,
                                              size: 24,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                net.ssid,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF111827),
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                net.isOpen ? "Open Network • Strong Signal" : "Encrypted • Strong Signal",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 38,
                                    child: isPrimary
                                        ? ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF111827),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(24),
                                              ),
                                              elevation: 0,
                                            ),
                                            onPressed: () => _verifyNetwork(net),
                                            child: const Text(
                                              "Verify",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          )
                                        : OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF1E293B),
                                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(24),
                                              ),
                                            ),
                                            onPressed: () => _verifyNetwork(net),
                                            child: const Text(
                                              "Verify",
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Handshake Verification Modal Overlay Bottom Sheet
class _HandshakeModalSheet extends StatefulWidget {
  final ApScanItem network;
  final NetworkService networkService;
  final Function(HandshakeResult result) onComplete;

  const _HandshakeModalSheet({
    required this.network,
    required this.networkService,
    required this.onComplete,
  });

  @override
  State<_HandshakeModalSheet> createState() => _HandshakeModalSheetState();
}

class _HandshakeModalSheetState extends State<_HandshakeModalSheet> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  HandshakeResult? _result;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _runHandshake();
  }

  Future<void> _runHandshake() async {
    final res = await widget.networkService.performMutualHandshake();
    if (mounted) {
      setState(() {
        _result = res;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = _result?.isVerified ?? true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 40,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 16),

          // Header: Title & Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Network Handshake Test",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "KIWI Anchor Hardware Validation",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Center Animated Pulse Radar Mascot
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.25),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isVerified
                                  ? const Color(0xFF34D399).withValues(alpha: 0.4)
                                  : const Color(0xFFF87171).withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isVerified ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    ),
                  ),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isVerified ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                        size: 32,
                        color: isVerified ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF111827)),
                  SizedBox(height: 12),
                  Text(
                    "Executing 4-Layer Ed25519 Handshake...",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ],
              ),
            )
          else if (isVerified)
            // STATE A: Verified View
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Hardware Authenticated",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF064E3B),
                            ),
                          ),
                          Text(
                            "Valid Anchor Signature",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Ed25519 cryptographic signature confirmed with Kiwi Trust Root. Session is shielded against ARP spoofing and rogue AP cloning.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (_result != null) widget.onComplete(_result!);
                      },
                      child: const Text(
                        "Safe to Browse",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // STATE B: Insecure View
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Untrusted / Rogue AP Detected",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7F1D1D),
                            ),
                          ),
                          Text(
                            "Hardware anchor mismatch",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Potential Man-in-the-Middle attack. The gateway failed challenge-response nonce verification. Transmitted packets may be intercepted.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        if (_result != null) widget.onComplete(_result!);
                      },
                      child: const Text(
                        "Disconnect Immediately",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
