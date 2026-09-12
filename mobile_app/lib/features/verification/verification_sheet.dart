import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class VerificationSheet extends StatefulWidget {
  final String networkName;
  final bool isHardwareVerified;
  final String hardwareFingerprint;
  final Function(bool connected)? onConnectionComplete;

  const VerificationSheet({
    super.key,
    required this.networkName,
    required this.isHardwareVerified,
    this.hardwareFingerprint = '8f:3a:29:b1:c4:7e',
    this.onConnectionComplete,
  });

  static Future<void> show(
    BuildContext context, {
    required String networkName,
    required bool isHardwareVerified,
    String hardwareFingerprint = '8f:3a:29:b1:c4:7e',
    Function(bool connected)? onConnectionComplete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VerificationSheet(
        networkName: networkName,
        isHardwareVerified: isHardwareVerified,
        hardwareFingerprint: hardwareFingerprint,
        onConnectionComplete: onConnectionComplete,
      ),
    );
  }

  @override
  State<VerificationSheet> createState() => _VerificationSheetState();
}

class _VerificationSheetState extends State<VerificationSheet> {
  bool _isLoading = true;
  int _stepIndex = 0;
  Timer? _timer;

  final List<String> _handshakeSteps = [
    'Querying 802.11az Attestation Payload...',
    'Deriving ECDSA P-256 Public Key Challenge...',
    'Validating TPM 2.0 Hardware Quote...',
    'Finalizing KIWI Trust Anchor Handshake...',
  ];

  @override
  void initState() {
    super.initState();
    _startHandshakeSimulation();
  }

  void _startHandshakeSimulation() {
    _timer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      if (_stepIndex < _handshakeSteps.length - 1) {
        setState(() {
          _stepIndex++;
        });
      } else {
        _timer?.cancel();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KiwiTheme.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F111827),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoading ? _buildLoadingState() : _buildResultState(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      key: const ValueKey('loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: KiwiTheme.textMuted.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(height: 12),
        const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(KiwiTheme.emerald),
            backgroundColor: KiwiTheme.emeraldSoft,
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Verifying Hardware Trust',
          style: TextStyle(
            color: KiwiTheme.textCharcoal,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connecting to "${widget.networkName}"',
          style: const TextStyle(
            color: KiwiTheme.textMuted,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Steps list
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KiwiTheme.bgSlate,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_handshakeSteps.length, (index) {
              final isDone = index < _stepIndex;
              final isCurrent = index == _stepIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    if (isDone)
                      const Icon(Icons.check_circle, size: 18, color: KiwiTheme.emerald)
                    else if (isCurrent)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(KiwiTheme.textCharcoal),
                        ),
                      )
                    else
                      const Icon(Icons.radio_button_unchecked, size: 18, color: KiwiTheme.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _handshakeSteps[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                          color: isCurrent
                              ? KiwiTheme.textCharcoal
                              : (isDone ? KiwiTheme.emeraldDark : KiwiTheme.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildResultState() {
    if (widget.isHardwareVerified) {
      return _buildSuccessState();
    } else {
      return _buildIronGateThreatState();
    }
  }

  Widget _buildSuccessState() {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag indicator
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: KiwiTheme.textMuted.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Emerald Shield Badge
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: KiwiTheme.emeraldSoft,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.verified_user_rounded,
              size: 44,
              color: KiwiTheme.emerald,
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Connection Secured',
          style: TextStyle(
            color: KiwiTheme.textCharcoal,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Hardware trust anchor verified via TPM 2.0 enclave.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: KiwiTheme.textMuted,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        // Hardware Fingerprint Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: KiwiTheme.bgSlate,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: KiwiTheme.emerald.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.memory_rounded, size: 16, color: KiwiTheme.emeraldDark),
                      SizedBox(width: 6),
                      Text(
                        'HARDWARE FINGERPRINT',
                        style: TextStyle(
                          color: KiwiTheme.emeraldDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: KiwiTheme.emeraldSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'TPM 2.0 MATCH',
                      style: TextStyle(
                        color: KiwiTheme.emeraldDark,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      widget.hardwareFingerprint,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: KiwiTheme.textCharcoal,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: KiwiTheme.textMuted),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.hardwareFingerprint));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hardware fingerprint copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copy Fingerprint',
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0x1F111827)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Network: ${widget.networkName}',
                    style: const TextStyle(fontSize: 12, color: KiwiTheme.textMuted),
                  ),
                  const Text(
                    'Proto: WPA3-Enterprise',
                    style: TextStyle(fontSize: 12, color: KiwiTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Continue Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              widget.onConnectionComplete?.call(true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KiwiTheme.emerald,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Continue to Browse',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildIronGateThreatState() {
    return Column(
      key: const ValueKey('threat'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag indicator
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: KiwiTheme.textMuted.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Crimson Warning Badge (Iron Gate)
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: KiwiTheme.crimsonSoft,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.gpp_bad_rounded,
              size: 46,
              color: KiwiTheme.crimson,
            ),
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Untrusted Network Detected',
          style: TextStyle(
            color: KiwiTheme.textCharcoal,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Iron Gate intercepted an unverified AP hardware signature.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: KiwiTheme.textMuted,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        // Threat Details Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: KiwiTheme.crimsonSoft.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: KiwiTheme.crimson.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, size: 18, color: KiwiTheme.crimsonDark),
                      SizedBox(width: 6),
                      Text(
                        'THREAT DETAILS',
                        style: TextStyle(
                          color: KiwiTheme.crimsonDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: KiwiTheme.crimson,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'HIGH RISK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Unverified Device / Spoof',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: KiwiTheme.crimsonDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hardware attestation failed. Evil Twin AP detected attempting packet inspection or man-in-the-middle spoofing.',
                style: TextStyle(
                  fontSize: 13,
                  color: KiwiTheme.textCharcoal,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Disconnect Now Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              widget.onConnectionComplete?.call(false);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KiwiTheme.crimson,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Disconnect Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
