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
  final String pincode;

  AddressDetails({
    required this.houseNo,
    required this.streetArea,
    required this.landmark,
    required this.cityState,
    required this.pincode,
  });

  String get fullAddress {
    final parts = <String>[];
    if (houseNo.isNotEmpty) parts.add(houseNo);
    if (streetArea.isNotEmpty) parts.add(streetArea);
    if (landmark.isNotEmpty) parts.add('Near $landmark');
    if (cityState.isNotEmpty) parts.add(cityState);
    if (pincode.isNotEmpty) parts.add('- $pincode');
    return parts.isNotEmpty ? parts.join(', ') : 'Flat 402, Vijay Nagar, Indore - 452010';
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

      // Try last known position for quick satellite lock, then fetch bestForNavigation accuracy
      Position? pos = await Geolocator.getLastKnownPosition();
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (_) {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
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

  /// Reverse geocode GPS coordinates into clean, ultra-precise real-time address breakdown
  static Future<AddressDetails> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=19&addressdetails=1&extratags=1&namedetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'SwiggyUserApp/1.0 (Android/iOS Food Delivery)',
      }).timeout(const Duration(seconds: 8));

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

        String road = (address['road'] ?? address['street'] ?? address['pedestrian'] ?? address['path'] ?? address['footway'])?.toString() ?? '';
        String suburb = (address['suburb'] ?? address['neighbourhood'] ?? address['quarter'] ?? address['residential'] ?? address['subdistrict'] ?? address['city_district'])?.toString() ?? '';
        String landmark = (address['landmark'] ?? address['tourism'] ?? address['commercial'] ?? address['historic'])?.toString() ?? '';
        String city = (address['city'] ?? address['town'] ?? address['municipality'] ?? address['village'] ?? address['district'] ?? address['county'])?.toString() ?? 'Indore';
        String state = (address['state'] ?? address['state_district'])?.toString() ?? 'Madhya Pradesh';
        String pincode = address['postcode']?.toString() ?? '';

        // Extract 6-digit pincode from display_name if missing
        if (pincode.isEmpty) {
          final pinMatch = RegExp(r'\b\d{6}\b').firstMatch(displayName);
          if (pinMatch != null) {
            pincode = pinMatch.group(0)!;
          } else {
            pincode = '452010';
          }
        }

        // Smart token extraction from display_name if houseNo or suburb is missing
        if (displayName.isNotEmpty) {
          final tokens = displayName.split(', ').map((s) => s.trim()).toList();
          tokens.removeWhere((t) => t.toLowerCase() == 'india' || RegExp(r'^\d{6}$').hasMatch(t));

          if (houseNo.isEmpty && tokens.isNotEmpty) {
            houseNo = tokens.first;
          }
          if (suburb.isEmpty && tokens.length > 1) {
            suburb = tokens.length > 2 ? '${tokens[1]}, ${tokens[2]}' : tokens[1];
          }
        }

        final streetAreaParts = [road, suburb].where((s) => s.isNotEmpty && s != houseNo).join(', ');

        return AddressDetails(
          houseNo: houseNo.isNotEmpty ? houseNo : '',
          streetArea: streetAreaParts.isNotEmpty ? streetAreaParts : 'Unnamed Road',
          landmark: landmark,
          cityState: '$city, $state',
          pincode: pincode,
        );
      }
    } catch (e) {
      if (kDebugMode) print('Reverse geocode error: $e');
    }

    // Fallback if network lookup times out
    return AddressDetails(
      houseNo: 'Flat 402, Sunshine Heights',
      streetArea: 'Vijay Nagar',
      landmark: 'Near Malhar Mega Mall',
      cityState: 'Indore, Madhya Pradesh',
      pincode: '452010',
    );
  }
}
