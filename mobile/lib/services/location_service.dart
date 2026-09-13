import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PlaceSuggestion {
  final String displayName;
  final String address;
  final double latitude;
  final double longitude;

  PlaceSuggestion({
    required this.displayName,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  String get formattedCoords =>
      "${latitude.toStringAsFixed(4)}° ${latitude >= 0 ? 'N' : 'S'}, ${longitude.toStringAsFixed(4)}° ${longitude >= 0 ? 'E' : 'W'}";
}

class LocationResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool isGpsDetected;

  LocationResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isGpsDetected,
  });

  String get formattedCoords =>
      "${latitude.toStringAsFixed(4)}° ${latitude >= 0 ? 'N' : 'S'}, ${longitude.toStringAsFixed(4)}° ${longitude >= 0 ? 'E' : 'W'}";
}

class LocationService {
  static const _prefLocationName = "kiwi_saved_location_name";
  static const _prefLocationCoords = "kiwi_saved_location_coords";
  static const _prefLocationLat = "kiwi_saved_location_lat";
  static const _prefLocationLon = "kiwi_saved_location_lon";

  final http.Client _client;

  LocationService({http.Client? client}) : _client = client ?? http.Client();

  /// Gets the currently saved/selected location or default fallback
  Future<LocationResult> getSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefLocationName) ?? "VIT University, Vellore";
    final lat = prefs.getDouble(_prefLocationLat) ?? 12.9692;
    final lon = prefs.getDouble(_prefLocationLon) ?? 79.1559;
    return LocationResult(
      name: name,
      address: name,
      latitude: lat,
      longitude: lon,
      isGpsDetected: false,
    );
  }

  /// Saves the active location anchor
  Future<void> saveLocation(LocationResult loc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLocationName, loc.name);
    await prefs.setString(_prefLocationCoords, loc.formattedCoords);
    await prefs.setDouble(_prefLocationLat, loc.latitude);
    await prefs.setDouble(_prefLocationLon, loc.longitude);
  }

  /// Automatically detects current GPS location from phone sensors and reverse-geocodes
  Future<LocationResult?> detectCurrentGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      String placeName = "Current Location";
      String fullAddress = "${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°";

      try {
        final uri = Uri.parse(
          "https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json&addressdetails=1",
        );
        final res = await _client.get(uri, headers: {"User-Agent": "KiwiCompanionMobile/1.0"}).timeout(
          const Duration(seconds: 4),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final displayName = (data['display_name'] as String?) ?? '';
          if (displayName.isNotEmpty) {
            final segments = displayName.split(',');
            placeName = segments.take(2).join(',').trim();
            fullAddress = displayName;
          }
        }
      } catch (_) {}

      final result = LocationResult(
        name: placeName,
        address: fullAddress,
        latitude: position.latitude,
        longitude: position.longitude,
        isGpsDetected: true,
      );

      await saveLocation(result);
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Live place search suggestions using OpenStreetMap Nominatim
  Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query.trim())}&format=json&addressdetails=1&limit=6",
      );

      final response = await _client.get(
        uri,
        headers: {"User-Agent": "KiwiCompanionMobile/1.0"},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data.map((item) {
          final map = item as Map<String, dynamic>;
          final displayName = (map['display_name'] as String?) ?? '';
          final lat = double.tryParse((map['lat'] as String?) ?? '0') ?? 0.0;
          final lon = double.tryParse((map['lon'] as String?) ?? '0') ?? 0.0;

          final parts = displayName.split(',');
          final mainTitle = parts.first.trim();
          final subTitle = parts.skip(1).take(3).join(',').trim();

          return PlaceSuggestion(
            displayName: mainTitle.isNotEmpty ? mainTitle : displayName,
            address: subTitle.isNotEmpty ? subTitle : displayName,
            latitude: lat,
            longitude: lon,
          );
        }).toList();
      }
    } catch (_) {}

    return [];
  }
}
