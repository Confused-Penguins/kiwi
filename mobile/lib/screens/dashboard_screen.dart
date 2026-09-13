import 'package:flutter/material.dart';
import '../models/verification_models.dart';
import '../services/crypto_service.dart';
import '../services/network_service.dart';
import '../services/storage_service.dart';
import 'location_screen.dart';
import 'scanner_screen.dart';
import 'status_screen.dart';
import 'threat_log_screen.dart';

class DashboardScreen extends StatefulWidget {
  final NetworkService networkService;

  const DashboardScreen({super.key, required this.networkService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _activeSsid = "Disconnected";
  bool _isSecured = false;
  int _threatCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final ssid = await widget.networkService.getConnectedWifiSsid();
    final storage = StorageService(CryptoService());
    await storage.init();
    final logs = storage.getThreatLogs();
    final isVerified = storage.isNetworkVerified(ssid);

    if (mounted) {
      setState(() {
        _activeSsid = ssid ?? "Disconnected";
        _threatCount = logs.length;
        _isSecured = (ssid != null && ssid.isNotEmpty) ? isVerified : false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EDF0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // TOP SECTION: Header, Avatar, Greeting
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Action Bar: Brand KIWI + Connected Wi-Fi Pill
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "KIWI",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _isSecured
                                            ? const Color(0xFF10B981)
                                            : _activeSsid != "Disconnected"
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF9CA3AF),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.wifi_rounded,
                                      size: 14,
                                      color: Color(0xFF111827),
                                    ),
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 160),
                                      child: Text(
                                        _activeSsid != "Disconnected" ? "Connected: $_activeSsid" : "Disconnected",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Kiwi Bird Mascot Circle
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: CustomPaint(
                                size: const Size(40, 40),
                                painter: _KiwiBirdPainter(),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Greeting & Subtext Headline
                          const Text(
                            "Hi User,\nLet's secure your\nconnection.",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              height: 1.18,
                              letterSpacing: -0.6,
                              color: Color(0xFF0B0F19),
                            ),
                          ),
                        ],
                      ),

                      // BOTTOM SECTION (BIGGER 4 CARDS)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.82,
                          children: [
                            // CARD 1: KIWI Scan
                            _DashboardGridCard(
                              iconBoxBg: const Color(0xFFF1F5F9),
                              icon: Icons.radar_rounded,
                              iconColor: const Color(0xFF0B0F19),
                              title: "KIWI Scan",
                              subtitle: "Find & Verify Wi-Fi",
                              subtitleColor: const Color(0xFF64748B),
                              onTap: () async {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ScannerScreen(networkService: widget.networkService),
                                  ),
                                );
                                if (res is HandshakeResult && mounted) {
                                  setState(() => _isSecured = res.isVerified);
                                }
                                _loadDashboardData();
                              },
                            ),

                            // CARD 2: Shield Status
                            _DashboardGridCard(
                              iconBoxBg: _isSecured ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                              icon: _isSecured ? Icons.shield_rounded : Icons.gpp_maybe_rounded,
                              iconColor: _isSecured ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              title: "Shield Status",
                              subtitle: _isSecured ? "Protected (Active)" : "Unverified (At Risk)",
                              subtitleColor: _isSecured ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              onTap: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StatusScreen(
                                        networkService: widget.networkService,
                                        targetSsid: _activeSsid != "Disconnected" ? _activeSsid : null,
                                      ),
                                    ),
                                  );
                                if (res is HandshakeResult && mounted) {
                                  setState(() => _isSecured = res.isVerified);
                                }
                                _loadDashboardData();
                              },
                            ),

                            // CARD 3: Incident Log
                            _DashboardGridCard(
                              iconBoxBg: const Color(0xFFF1F5F9),
                              icon: Icons.shield_outlined,
                              iconColor: const Color(0xFF0B0F19),
                              title: "Incident Log",
                              subtitle: "$_threatCount Threats Detected",
                              subtitleColor: const Color(0xFF64748B),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ThreatLogScreen(),
                                  ),
                                );
                                _loadDashboardData();
                              },
                            ),

                            // CARD 4: Location
                            _DashboardGridCard(
                              iconBoxBg: const Color(0xFFF1F5F9),
                              icon: Icons.location_on_outlined,
                              iconColor: const Color(0xFF0B0F19),
                              title: "Location",
                              subtitle: "Set Area",
                              subtitleColor: const Color(0xFF64748B),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LocationScreen(),
                                  ),
                                );
                                _loadDashboardData();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardGridCard extends StatelessWidget {
  final Color iconBoxBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final VoidCallback onTap;

  const _DashboardGridCard({
    required this.iconBoxBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBoxBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 26,
                    color: iconColor,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B0F19),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Kiwi Bird Mascot Painter
class _KiwiBirdPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.fill;

    final path = Path();
    // Body curve
    path.addOval(Rect.fromLTWH(size.width * 0.15, size.height * 0.25, size.width * 0.6, size.height * 0.55));
    canvas.drawPath(path, paint);

    // Beak
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.4),
      Offset(size.width * 0.95, size.height * 0.52),
      paint,
    );

    // Eye
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.38), 1.5, fillPaint);

    // Legs
    canvas.drawLine(
      Offset(size.width * 0.35, size.height * 0.8),
      Offset(size.width * 0.35, size.height * 0.95),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.8),
      Offset(size.width * 0.52, size.height * 0.95),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
