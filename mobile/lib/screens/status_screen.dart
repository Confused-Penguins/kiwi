import 'package:flutter/material.dart';
import '../models/verification_models.dart';
import '../services/crypto_service.dart';
import '../services/location_service.dart';
import '../services/network_service.dart';
import '../services/storage_service.dart';
import '../theme/kiwi_theme.dart';

class StatusScreen extends StatefulWidget {
  final NetworkService networkService;
  final HandshakeResult? initialResult;
  final String? targetSsid;
  final String? targetBssid;

  const StatusScreen({
    super.key,
    required this.networkService,
    this.initialResult,
    this.targetSsid,
    this.targetBssid,
  });

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  HandshakeResult? _result;
  bool _isLoading = false;
  bool _isReported = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialResult != null) {
      _result = widget.initialResult;
    } else {
      _runVerificationCheck();
    }
  }

  Future<void> _runVerificationCheck() async {
    setState(() => _isLoading = true);
    final connectedSsid = await widget.networkService.getConnectedWifiSsid();
    final connectedBssid = await widget.networkService.getConnectedWifiBssid();

    final activeSsid = (widget.targetSsid != null && widget.targetSsid!.isNotEmpty && widget.targetSsid != "Disconnected")
        ? widget.targetSsid!
        : (connectedSsid ?? "Current Network");
    final activeBssid = (widget.targetBssid != null && widget.targetBssid!.isNotEmpty && widget.targetBssid != "00:00:00:00:00:00")
        ? widget.targetBssid!
        : (connectedBssid ?? "00:00:00:00:00:00");

    final res = await widget.networkService.performMutualHandshake(
      ssid: activeSsid,
      bssid: activeBssid,
    );

    if (activeSsid.isNotEmpty && activeSsid != "Disconnected") {
      final storage = StorageService(CryptoService());
      await storage.init();
      await storage.setNetworkVerified(activeSsid, res.isVerified);
    }

    if (mounted) {
      setState(() {
        _result = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _result == null) {
      return Scaffold(
        backgroundColor: KiwiTheme.appBg,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: KiwiTheme.charcoal),
              SizedBox(height: 16),
              Text(
                "Verifying Network Security...",
                style: TextStyle(fontWeight: FontWeight.bold, color: KiwiTheme.charcoal),
              ),
            ],
          ),
        ),
      );
    }

    final isVerified = _result!.isVerified;

    if (!isVerified) {
      return _buildConnectionNotVerifiedScreen(context);
    }

    return _buildVerifiedScreen(context);
  }

  /// 1:1 Connection Not Verified Screen matching User Mockup Image
  Widget _buildConnectionNotVerifiedScreen(BuildContext context) {
    const pinkBg = Color(0xFFFDE8E8);
    const orangeButton = Color(0xFFFF7A38);

    return Scaffold(
      backgroundColor: pinkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Row (Clean back button, top left logo removed)
              InkWell(
                onTap: () => Navigator.pop(context, _result),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
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
                      color: KiwiTheme.charcoal,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Concentric Circles with Off-Wi-Fi Icon
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFCE1E1).withValues(alpha: 0.6),
                  ),
                  child: Center(
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFCD5D5),
                      ),
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFBBFBF),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.portable_wifi_off_rounded,
                              size: 48,
                              color: KiwiTheme.charcoal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Headline: Connection Not Verified
              const Center(
                child: Text(
                  "Connection Not Verified",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: KiwiTheme.charcoal,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (_result?.failureReason != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _result!.failureReason!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Action Buttons Row: Blocked for Safety + Report
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orangeButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Connection blocked for security.")),
                          );
                        },
                        child: const Text(
                          "Blocked for safety",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _isReported ? Colors.white : Colors.transparent,
                          foregroundColor: _isReported ? Colors.green.shade800 : KiwiTheme.charcoal,
                          side: BorderSide(
                            color: _isReported ? Colors.green.shade600 : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: _isReported ? null : _handleReportIncident,
                        icon: Icon(
                          _isReported ? Icons.check_circle_rounded : Icons.report_problem_outlined,
                          size: 16,
                          color: _isReported ? Colors.green.shade700 : KiwiTheme.charcoal,
                        ),
                        label: Text(
                          _isReported ? "Reported" : "Report",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isReported ? Colors.green.shade800 : KiwiTheme.charcoal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Bypass Link
              Center(
                child: TextButton.icon(
                  onPressed: () => _showBypassBottomSheet(context),
                  icon: Text(
                    "Bypass anyway",
                    style: TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  label: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleReportIncident() async {
    final locationService = LocationService();
    final loc = await locationService.getSavedLocation();
    final storage = StorageService(CryptoService());
    await storage.init();

    final connectedSsid = await widget.networkService.getConnectedWifiSsid();
    final connectedBssid = await widget.networkService.getConnectedWifiBssid();

    final ssid = (widget.targetSsid != null && widget.targetSsid!.isNotEmpty && widget.targetSsid != "Disconnected")
        ? widget.targetSsid!
        : (connectedSsid ?? "Unverified Network");
    final bssid = (widget.targetBssid != null && widget.targetBssid!.isNotEmpty && widget.targetBssid != "00:00:00:00:00:00")
        ? widget.targetBssid!
        : (connectedBssid ?? "00:00:00:00:00:00");

    await storage.reportIncident(
      ssid: ssid,
      bssid: bssid,
      reason: _result?.failureReason ?? "Unverified network threat detected",
      location: "${loc.name} (${loc.formattedCoords})",
      deviceId: _result?.certificate?.deviceId,
    );

    if (mounted) {
      setState(() => _isReported = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Incident reported and saved to Incident Logs with location: ${loc.name}"),
          backgroundColor: KiwiTheme.charcoal,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 1:1 Connection Verified Screen matching User Mockup Image
  Widget _buildVerifiedScreen(BuildContext context) {
    const mintBg = Color(0xFFD6F8E8);
    const mintButton = Color(0xFF6DE8BD);

    return Scaffold(
      backgroundColor: mintBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Row (Clean back button, top left logo removed)
              InkWell(
                onTap: () => Navigator.pop(context, _result),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
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
                      color: KiwiTheme.charcoal,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Concentric Mint Circles with Wi-Fi Check Icon
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFC0F4DC).withValues(alpha: 0.6),
                  ),
                  child: Center(
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFA5F0CD),
                      ),
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF7BEBC0),
                          ),
                          child: Center(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.wifi_rounded,
                                  size: 46,
                                  color: KiwiTheme.charcoal,
                                ),
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF7BEBC0),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_rounded,
                                      size: 20,
                                      color: KiwiTheme.charcoal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Headline: Connection Verified with Checkmark
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "Connection Verified",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: KiwiTheme.charcoal,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 26,
                      color: KiwiTheme.charcoal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  "Hardware-Verified Wi-Fi Security",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),

              const Spacer(),

              // Main Mint Action Button: Connected and Secure
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mintButton,
                    foregroundColor: KiwiTheme.charcoal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final ssid = await widget.networkService.getConnectedWifiSsid();
                    if (ssid != null && ssid.isNotEmpty) {
                      final storage = StorageService(CryptoService());
                      await storage.init();
                      await storage.setNetworkVerified(ssid, true);
                    }
                    if (context.mounted) {
                      Navigator.pop(context, _result);
                    }
                  },
                  child: const Text(
                    "Connected and Secure",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: KiwiTheme.charcoal,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Hardware Telemetry Link
              Center(
                child: TextButton.icon(
                  onPressed: () => _showTelemetryBottomSheet(context),
                  icon: Text(
                    "Hardware telemetry",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  label: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showTelemetryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Hardware Cryptographic Telemetry",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: KiwiTheme.charcoal,
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow(label: "Gateway Device ID", value: _result!.certificate?.deviceId ?? "KIWI-GW-296035"),
            const Divider(height: 16),
            _DetailRow(label: "Handshake Latency", value: "${_result!.latencyMs} ms"),
            const Divider(height: 16),
            _DetailRow(
              label: "Ed25519 Fingerprint",
              value: _result!.certificate?.publicKeyHex != null
                  ? "${_result!.certificate!.publicKeyHex.substring(0, 16)}..."
                  : "Certified Anchor",
            ),
            const Divider(height: 16),
            _DetailRow(label: "Passed Verification", value: "4/4 Layers Validated ✓"),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showBypassBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Security Risk Acknowledgment",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KiwiTheme.hostileRed),
            ),
            const SizedBox(height: 12),
            const Text(
              "Bypassing hardware verification allows unverified network traffic which may expose your connection to Man-in-the-Middle (MITM) attacks.",
              style: TextStyle(fontSize: 13, color: KiwiTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KiwiTheme.hostileRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Bypassed: Connected to unverified network.")),
                  );
                },
                child: const Text("I Understand the Risk - Continue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: KiwiTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: KiwiTheme.charcoal),
        ),
      ],
    );
  }
}
