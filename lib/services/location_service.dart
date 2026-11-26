import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class AddressDetails {
  final String houseNo;
  final String streetArea;
  final String landmark;
  final String cityState;
  final String city; // Added isolated city name for DB matching
  final String pincode;
  final double? latitude;
  final double? longitude;

  AddressDetails({
    required this.houseNo,
    required this.streetArea,
    required this.landmark,
    required this.cityState,
    required this.city,
    required this.pincode,
    this.latitude,
    this.longitude,
  });

  String get fullAddress {
    final parts = <String>[];
    if (houseNo.isNotEmpty) parts.add(houseNo);
    if (streetArea.isNotEmpty) parts.add(streetArea);
    if (landmark.isNotEmpty) parts.add('Near $landmark');
    if (cityState.isNotEmpty) parts.add(cityState);

    String formatted = parts.join(', ');
    if (pincode.isNotEmpty) {
      formatted = formatted.isNotEmpty ? '$formatted - $pincode' : pincode;
    }

    if (formatted.isNotEmpty) return formatted;
    if (latitude != null && longitude != null) {
      return 'Lat: ${latitude!.toStringAsFixed(6)}, Lng: ${longitude!.toStringAsFixed(6)}';
    }
    return '';
  }
}

class LocationService {
  /// Request permissions and fetch current ultra-high accuracy GPS coordinates
  static Future<Position?> getCurrentLocation({
    void Function(String message)? onError,
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('GPS Location services are turned off. Opening location settings...');
        await Geolocator.openLocationSettings();
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onError?.call('Location permission denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onError?.call('Location permissions are permanently denied. Please enable them in system settings.');
        await Geolocator.openAppSettings();
        return null;
      }

      final Position? lastKnown = await Geolocator.getLastKnownPosition();
      Position? pos;

      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (_) {
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (_) {
          pos = lastKnown;
        }
      }

      if (pos == null) {
        onError?.call('Unable to determine GPS coordinates.');
        return null;
      }

      await StorageService.setString('userLat', pos.latitude.toString());
      await StorageService.setString('userLng', pos.longitude.toString());

      return pos;
    } catch (e) {
      if (kDebugMode) print('LocationService error: $e');
      onError?.call('Failed to get high-accuracy location: $e');
      return null;
    }
  }

  /// Reverse geocode GPS coordinates into a real-time address breakdown
  static Future<AddressDetails> reverseGeocode(double lat, double lng) async {
    // 1. Primary lookup: OpenStreetMap Nominatim
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1&extratags=1&namedetails=1',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FlutterDeliveryClient/1.0',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};
        final displayName = data['display_name']?.toString() ?? '';

        String houseNo = (address['house_number'] ??
            address['building'] ??
            address['flat'] ??
            address['door_number'] ??
            address['unit'] ??
            address['house_name'] ??
            address['amenity'] ??
            address['shop'] ??
            address['office'])
            ?.toString() ??
            '';

        final String road = (address['road'] ??
            address['street'] ??
            address['pedestrian'] ??
            address['path'] ??
            address['footway'])
            ?.toString() ??
            '';

        String suburb = (address['suburb'] ??
            address['neighbourhood'] ??
            address['quarter'] ??
            address['residential'] ??
            address['subdistrict'] ??
            address['city_district'])
            ?.toString() ??
            '';

        final String landmark = (address['landmark'] ??
            address['tourism'] ??
            address['commercial'] ??
            address['historic'])
            ?.toString() ??
            '';

        final String city = (address['city'] ??
            address['town'] ??
            address['municipality'] ??
            address['village'] ??
            address['district'] ??
            address['county'])
            ?.toString() ??
            '';

        final String state = (address['state'] ?? address['state_district'])?.toString() ?? '';
        String pincode = address['postcode']?.toString() ?? '';

        if (pincode.isEmpty && displayName.isNotEmpty) {
          final pinMatch = RegExp(r'\b\d{6}\b').firstMatch(displayName);
          if (pinMatch != null) {
            pincode = pinMatch.group(0)!;
          }
        }

        if (displayName.isNotEmpty) {
          final tokens = displayName.split(', ').map((s) => s.trim()).toList();
          tokens.removeWhere(
                (t) => t.toLowerCase() == 'india' || RegExp(r'^\d{6}$').hasMatch(t),
          );

          if (houseNo.isEmpty && tokens.isNotEmpty) {
            houseNo = tokens.first;
          }
          if (suburb.isEmpty && tokens.length > 1) {
            suburb = tokens.length > 2 ? '${tokens[1]}, ${tokens[2]}' : tokens[1];
          }
        }

        final streetAreaParts = [road, suburb]
            .where((s) => s.isNotEmpty && s != houseNo)
            .join(', ');
        final cityStateParts = [city, state].where((s) => s.isNotEmpty).join(', ');

        if (streetAreaParts.isNotEmpty || cityStateParts.isNotEmpty) {
          return AddressDetails(
            houseNo: houseNo,
            streetArea: streetAreaParts,
            landmark: landmark,
            cityState: cityStateParts,
            city: city.isNotEmpty ? city : 'Indore',
            pincode: pincode,
            latitude: lat,
            longitude: lng,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('Nominatim reverse geocode error: $e');
    }

    // 2. Secondary lookup if Nominatim fails or rate-limits
    try {
      final fallbackUrl = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=en',
      );
      final response = await http.get(fallbackUrl).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String locality = data['locality']?.toString() ?? '';
        final String city = data['city']?.toString() ?? '';
        final String state = data['principalSubdivision']?.toString() ?? '';
        final String pincode = data['postcode']?.toString() ?? '';

        final cityStateParts = [city, state].where((s) => s.isNotEmpty).join(', ');

        return AddressDetails(
          houseNo: '',
          streetArea: locality,
          landmark: '',
          cityState: cityStateParts,
          city: city.isNotEmpty ? city : 'Indore',
          pincode: pincode,
          latitude: lat,
          longitude: lng,
        );
      }
    } catch (e) {
      if (kDebugMode) print('Secondary reverse geocode error: $e');
    }

    // 3. Offline fallback: return actual GPS coordinates instead of dummy text
    return AddressDetails(
      houseNo: '',
      streetArea: 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
      landmark: '',
      cityState: '',
      city: 'Indore',
      pincode: '',
      latitude: lat,
      longitude: lng,
    );
  }
}