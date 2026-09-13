// KIWI Incident Logs & Threat Audit Screen
// Displays reported incidents, blocked evil twins, and forensic metadata with geolocation.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/verification_models.dart';
import '../services/crypto_service.dart';
import '../services/storage_service.dart';
import '../theme/kiwi_theme.dart';

class ThreatLogScreen extends StatefulWidget {
  const ThreatLogScreen({super.key});

  @override
  State<ThreatLogScreen> createState() => _ThreatLogScreenState();
}

class _ThreatLogScreenState extends State<ThreatLogScreen> {
  late StorageService _storageService;
  List<ThreatLogEntry> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final crypto = CryptoService();
    _storageService = StorageService(crypto);
    await _storageService.init();

    if (mounted) {
      setState(() {
        _logs = _storageService.getThreatLogs();
        _isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear Incident Logs?"),
        content: const Text(
          "Are you sure you want to permanently clear all recorded security incident logs?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel", style: TextStyle(color: KiwiTheme.charcoal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KiwiTheme.hostileRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storageService.clearThreatLogs();
      if (mounted) {
        setState(() => _logs = []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Incident logs cleared.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Scaffold(
      backgroundColor: KiwiTheme.appBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: KiwiTheme.charcoal),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Incident Logs",
          style: TextStyle(
            color: KiwiTheme.charcoal,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: KiwiTheme.charcoal),
              tooltip: "Clear Logs",
              onPressed: _clearLogs,
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: KiwiTheme.charcoal))
            : _logs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: KiwiTheme.cardBg,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              size: 48,
                              color: KiwiTheme.verifiedDark,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "No Incidents Recorded",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: KiwiTheme.charcoal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Your network security logs and user-reported threats will appear here with location and timestamp details.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: KiwiTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final item = _logs[index];
                      final isReport = item.isReported;
                      final isBypassed = item.bypassed;

                      final badgeColor = isReport
                          ? const Color(0xFFFF7A38)
                          : isBypassed
                              ? const Color(0xFFF59E0B)
                              : KiwiTheme.hostileRose;

                      final badgeText = isReport
                          ? "REPORTED"
                          : isBypassed
                              ? "BYPASSED"
                              : "BLOCKED";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: KiwiTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Badge + Timestamp
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: badgeColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  dateFormat.format(item.timestamp),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: KiwiTheme.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Threat Title / Reason
                            Text(
                              item.failureReason,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: KiwiTheme.charcoal,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Network Meta: SSID & BSSID
                            Row(
                              children: [
                                const Icon(Icons.wifi_rounded, size: 14, color: KiwiTheme.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  item.ssid,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: KiwiTheme.charcoal,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "(${item.bssid})",
                                  style: const TextStyle(fontSize: 11, color: KiwiTheme.textMuted),
                                ),
                              ],
                            ),

                            // Location if available
                            if (item.location != null && item.location!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: KiwiTheme.telemetryBlue),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.location!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: KiwiTheme.telemetryBlue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
