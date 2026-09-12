import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../discovery/discovery_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _activeNavIndex = 0;
  bool _isProtected = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KiwiTheme.bgSlate,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable Content Area
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Profile Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: KiwiTheme.textCharcoal,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x1F111827),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.shield_moon_rounded,
                                color: KiwiTheme.emerald,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'KIWI TRUST ANCHOR',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: KiwiTheme.textMuted,
                                ),
                              ),
                              Text(
                                'Hardware Verified',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: KiwiTheme.textCharcoal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: KiwiTheme.emeraldSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            CircleAvatar(
                              radius: 4,
                              backgroundColor: KiwiTheme.emerald,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Enclave Online',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: KiwiTheme.emeraldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Greeting Section
                  const Text(
                    "Hi User,",
                    style: TextStyle(
                      fontSize: 16,
                      color: KiwiTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Let's secure your connection.",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: KiwiTheme.textCharcoal,
                      letterSpacing: -0.8,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Mascot & Hardware Status Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: KiwiTheme.cardWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x0A111827), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08111827),
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: KiwiTheme.emeraldSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'TPM 2.0 ATTESTATION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: KiwiTheme.emeraldDark,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Hardware Trust Active',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: KiwiTheme.textCharcoal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Zero-trust Wi-Fi verification listening for hardware signatures.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: KiwiTheme.textMuted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Line-art Kiwi Mascot Emblem
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: KiwiTheme.bgSlate,
                            shape: BoxShape.circle,
                            border: Border.all(color: KiwiTheme.textCharcoal.withValues(alpha: 0.1), width: 1.5),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.psychology_rounded,
                              size: 34,
                              color: KiwiTheme.textCharcoal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'QUICK ACTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: KiwiTheme.textMuted,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2x2 Action Card Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.05,
                    children: [
                      // 1. KIWI Scan (Navigates to DiscoveryScreen)
                      _buildActionCard(
                        title: 'KIWI Scan',
                        subtitle: 'Scan nearby anchors',
                        icon: Icons.radar_rounded,
                        iconBgColor: KiwiTheme.textCharcoal,
                        iconColor: Colors.white,
                        badgeText: 'Tap to Scan',
                        badgeBg: KiwiTheme.bgSlate,
                        badgeTextColor: KiwiTheme.textCharcoal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DiscoveryScreen(),
                            ),
                          );
                        },
                      ),

                      // 2. Shield Status
                      _buildActionCard(
                        title: 'Shield Status',
                        subtitle: _isProtected ? 'Enclave active' : 'Protection off',
                        icon: Icons.verified_user_rounded,
                        iconBgColor: _isProtected ? KiwiTheme.emeraldSoft : KiwiTheme.crimsonSoft,
                        iconColor: _isProtected ? KiwiTheme.emerald : KiwiTheme.crimson,
                        badgeText: _isProtected ? 'Protected' : 'Inactive',
                        badgeBg: _isProtected ? KiwiTheme.emeraldSoft : KiwiTheme.crimsonSoft,
                        badgeTextColor: _isProtected ? KiwiTheme.emeraldDark : KiwiTheme.crimsonDark,
                        onTap: () {
                          setState(() {
                            _isProtected = !_isProtected;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _isProtected ? 'Shield Status set to Protected' : 'Shield Status set to Inactive',
                              ),
                            ),
                          );
                        },
                      ),

                      // 3. Incident Log
                      _buildActionCard(
                        title: 'Incident Log',
                        subtitle: '100% clean log',
                        icon: Icons.security_rounded,
                        iconBgColor: KiwiTheme.bgSlate,
                        iconColor: KiwiTheme.textCharcoal,
                        badgeText: '0 threats blocked',
                        badgeBg: KiwiTheme.bgSlate,
                        badgeTextColor: KiwiTheme.textMuted,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Incident Log: 0 threats detected in last 24h')),
                          );
                        },
                      ),

                      // 4. Trust Profile
                      _buildActionCard(
                        title: 'Trust Profile',
                        subtitle: 'Default enclave key',
                        icon: Icons.badge_rounded,
                        iconBgColor: KiwiTheme.bgSlate,
                        iconColor: KiwiTheme.textCharcoal,
                        badgeText: 'Public Guest Mode',
                        badgeBg: KiwiTheme.bgSlate,
                        badgeTextColor: KiwiTheme.textMuted,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Trust Profile: Public Guest Mode active')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Floating Pill Navigation Dock
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: KiwiTheme.textCharcoal,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33111827),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home_filled, 'Home'),
                    _buildNavItem(1, Icons.radar_rounded, 'Scan', onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DiscoveryScreen(),
                        ),
                      );
                    }),
                    _buildNavItem(2, Icons.shield_rounded, 'Shield'),
                    _buildNavItem(3, Icons.person_rounded, 'Profile'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String badgeText,
    required Color badgeBg,
    required Color badgeTextColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: KiwiTheme.cardWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x0A111827), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06111827),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: KiwiTheme.textMuted,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: KiwiTheme.textCharcoal,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {VoidCallback? onTap}) {
    final isSelected = _activeNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _activeNavIndex = index);
        if (onTap != null) onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? KiwiTheme.emerald : Colors.white70,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
