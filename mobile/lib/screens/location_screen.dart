import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme/kiwi_theme.dart';

class LocationScreen extends StatefulWidget {
  final LocationService? locationService;

  const LocationScreen({super.key, this.locationService});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> with SingleTickerProviderStateMixin {
  late final LocationService _locationService;
  late AnimationController _compassController;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  LocationResult _currentLocation = LocationResult(
    name: "Detecting location...",
    address: "Acquiring GPS fix...",
    latitude: 12.9692,
    longitude: 79.1559,
    isGpsDetected: false,
  );

  bool _isGpsLoading = false;
  bool _isSearching = false;
  List<PlaceSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? LocationService();
    _compassController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _loadInitialLocation();
  }

  Future<void> _loadInitialLocation() async {
    final saved = await _locationService.getSavedLocation();
    if (mounted) {
      setState(() => _currentLocation = saved);
    }
    // Automatically detect GPS location
    _autoDetectGpsLocation();
  }

  Future<void> _autoDetectGpsLocation() async {
    setState(() => _isGpsLoading = true);
    final detected = await _locationService.detectCurrentGpsLocation();
    if (mounted) {
      setState(() {
        _isGpsLoading = false;
        if (detected != null) {
          _currentLocation = detected;
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      final results = await _locationService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectSuggestion(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    setState(() {
      _suggestions = [];
      _currentLocation = LocationResult(
        name: suggestion.displayName,
        address: suggestion.address,
        latitude: suggestion.latitude,
        longitude: suggestion.longitude,
        isGpsDetected: false,
      );
    });
    await _locationService.saveLocation(_currentLocation);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Location anchor set to: ${suggestion.displayName}"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _compassController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KiwiTheme.appBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: KiwiTheme.charcoal),
          onPressed: () => Navigator.pop(context, _currentLocation),
        ),
        title: const Text(
          "Location Anchor",
          style: TextStyle(
            color: KiwiTheme.charcoal,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rotating Compass Radar Graphic
              Center(
                child: AnimatedBuilder(
                  animation: _compassController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _compassController.value * 2 * math.pi,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: KiwiTheme.cardBg,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: KiwiTheme.telemetryBlue.withValues(alpha: 0.12),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.explore_rounded,
                            size: 56,
                            color: KiwiTheme.telemetryBlue,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Active Location Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: KiwiTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _currentLocation.isGpsDetected ? Icons.gps_fixed_rounded : Icons.location_on_rounded,
                              color: KiwiTheme.telemetryBlue,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currentLocation.isGpsDetected ? "GPS AUTO-DETECTED" : "ACTIVE LOCATION ANCHOR",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: KiwiTheme.telemetryBlue,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        if (_isGpsLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: KiwiTheme.telemetryBlue),
                          )
                        else
                          InkWell(
                            onTap: _autoDetectGpsLocation,
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.refresh_rounded, size: 20, color: KiwiTheme.telemetryBlue),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currentLocation.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: KiwiTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentLocation.formattedCoords,
                      style: const TextStyle(
                        fontSize: 12,
                        color: KiwiTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Search Places Bar
              const Text(
                "Search Places (Google Maps Style)",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: KiwiTheme.charcoal,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: KiwiTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: KiwiTheme.charcoal, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Enter place name, landmark or city...",
                    hintStyle: const TextStyle(color: KiwiTheme.textMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: KiwiTheme.charcoal),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: KiwiTheme.charcoal),
                            ),
                          )
                        : _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: KiwiTheme.textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              // Live Search Suggestions Dropdown List
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: KiwiTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _suggestions.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 48),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: KiwiTheme.telemetryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on_outlined,
                            color: KiwiTheme.telemetryBlue,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          item.displayName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: KiwiTheme.charcoal,
                          ),
                        ),
                        subtitle: Text(
                          item.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: KiwiTheme.textSecondary),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: KiwiTheme.textMuted),
                        onTap: () => _selectSuggestion(item),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Auto-Detect GPS Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KiwiTheme.charcoal,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isGpsLoading ? null : _autoDetectGpsLocation,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    _isGpsLoading ? "Detecting GPS location..." : "Use Current GPS Location",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
