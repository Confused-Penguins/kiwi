import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../verification/verification_sheet.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  int _selectedSegment = 0; // 0: Current GPS, 1: Search City/Venue
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KiwiTheme.bgSlate,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nearby Networks',
          style: TextStyle(
            color: KiwiTheme.textCharcoal,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filter settings updated')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Segmented Toggle Control
              Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0x0A111827)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedSegment = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _selectedSegment == 0
                                ? KiwiTheme.textCharcoal
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                size: 16,
                                color: _selectedSegment == 0
                                    ? Colors.white
                                    : KiwiTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Current GPS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedSegment == 0
                                      ? Colors.white
                                      : KiwiTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedSegment = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _selectedSegment == 1
                                ? KiwiTheme.textCharcoal
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 16,
                                color: _selectedSegment == 1
                                    ? Colors.white
                                    : KiwiTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Search City/Venue',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedSegment == 1
                                      ? Colors.white
                                      : KiwiTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_selectedSegment == 1) ...[
                const SizedBox(height: 16),
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: KiwiTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: KiwiTheme.textMuted, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: const InputDecoration(
                            hintText: 'Enter venue or city name...',
                            hintStyle: TextStyle(color: KiwiTheme.textMuted, fontSize: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close_rounded, color: KiwiTheme.textMuted, size: 18),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedSegment == 0 ? 'AVAILABLE ANCHORS' : 'SEARCH RESULTS',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: KiwiTheme.textMuted,
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.wifi_tethering_rounded, size: 14, color: KiwiTheme.emerald),
                      SizedBox(width: 4),
                      Text(
                        'Scanning Live',
                        style: TextStyle(
                          fontSize: 12,
                          color: KiwiTheme.emeraldDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Network Cards List
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (_searchQuery.isEmpty || 'Station_Guest_WiFi'.toLowerCase().contains(_searchQuery.toLowerCase()))
                      _buildNetworkCard(
                        context,
                        ssid: 'Station_Guest_WiFi',
                        isVerified: true,
                        bssid: '8f:3a:29:b1:c4:7e',
                        signal: '5 GHz • Excellent',
                        securityText: 'Hardware Verified (TPM 2.0)',
                        buttonText: 'Test & Connect',
                      ),
                    const SizedBox(height: 14),
                    if (_searchQuery.isEmpty || 'Airport_Free_Network'.toLowerCase().contains(_searchQuery.toLowerCase()))
                      _buildNetworkCard(
                        context,
                        ssid: 'Airport_Free_Network',
                        isVerified: false,
                        bssid: 'Unverified AP',
                        signal: '2.4 GHz • Fair',
                        securityText: 'Legacy Open (No Hardware Proof)',
                        buttonText: 'Connect',
                      ),
                    const SizedBox(height: 14),
                    if (_searchQuery.isEmpty || 'CoffeeShop_5G_Anchor'.toLowerCase().contains(_searchQuery.toLowerCase()))
                      _buildNetworkCard(
                        context,
                        ssid: 'CoffeeShop_5G_Anchor',
                        isVerified: true,
                        bssid: '4c:91:a3:7e:10:b2',
                        signal: '5 GHz • Full Bar',
                        securityText: 'Hardware Verified (KIWI)',
                        buttonText: 'Test & Connect',
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkCard(
    BuildContext context, {
    required String ssid,
    required bool isVerified,
    required String bssid,
    required String signal,
    required String securityText,
    required String buttonText,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KiwiTheme.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x0A111827), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111827),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Network Icon Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isVerified ? KiwiTheme.emeraldSoft : KiwiTheme.crimsonSoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isVerified ? Icons.shield_rounded : Icons.wifi_off_rounded,
                    color: isVerified ? KiwiTheme.emerald : KiwiTheme.crimson,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ssid,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: KiwiTheme.textCharcoal,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      signal,
                      style: const TextStyle(
                        fontSize: 13,
                        color: KiwiTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Security Status Pill Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isVerified
                  ? KiwiTheme.emeraldSoft.withValues(alpha: 0.6)
                  : KiwiTheme.crimsonSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isVerified ? Icons.verified_rounded : Icons.warning_amber_rounded,
                  size: 16,
                  color: isVerified ? KiwiTheme.emeraldDark : KiwiTheme.crimsonDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    securityText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isVerified ? KiwiTheme.emeraldDark : KiwiTheme.crimsonDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                VerificationSheet.show(
                  context,
                  networkName: ssid,
                  isHardwareVerified: isVerified,
                  hardwareFingerprint: bssid,
                  onConnectionComplete: (connected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          connected
                              ? 'Successfully established trust link with $ssid'
                              : 'Connection rejected. Iron Gate protection active.',
                        ),
                        backgroundColor: connected ? KiwiTheme.emerald : KiwiTheme.crimson,
                      ),
                    );
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isVerified ? KiwiTheme.textCharcoal : KiwiTheme.crimson,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
