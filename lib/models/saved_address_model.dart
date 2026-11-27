import 'dart:convert';

class SavedAddressModel {
  final String id;
  final String label; // 'HOME', 'WORK', 'OTHER'
  final String houseNo;
  final String streetArea;
  final String landmark;
  final String cityState;
  final String pincode;
  final double? latitude;
  final double? longitude;
  final String receiverName;
  final String receiverPhone;

  SavedAddressModel({
    required this.id,
    this.label = 'HOME',
    required this.houseNo,
    required this.streetArea,
    required this.landmark,
    required this.cityState,
    required this.pincode,
    this.latitude,
    this.longitude,
    required this.receiverName,
    required this.receiverPhone,
  });

  String get fullAddress {
    final parts = <String>[];
    if (houseNo.trim().isNotEmpty) parts.add(houseNo.trim());
    if (streetArea.trim().isNotEmpty) parts.add(streetArea.trim());
    if (landmark.trim().isNotEmpty) {
      final l = landmark.trim();
      if (l.toLowerCase().startsWith('near') || l.toLowerCase().startsWith('landmark')) {
        parts.add(l);
      } else {
        parts.add('Near $l');
      }
    }
    if (cityState.trim().isNotEmpty) parts.add(cityState.trim());

    String formatted = parts.join(', ');
    if (pincode.trim().isNotEmpty) {
      formatted = formatted.isNotEmpty ? '$formatted - ${pincode.trim()}' : pincode.trim();
    }
    return formatted;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'houseNo': houseNo,
      'streetArea': streetArea,
      'landmark': landmark,
      'cityState': cityState,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
    };
  }

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      label: json['label']?.toString() ?? 'HOME',
      houseNo: json['houseNo']?.toString() ?? '',
      streetArea: json['streetArea']?.toString() ?? '',
      landmark: json['landmark']?.toString() ?? '',
      cityState: json['cityState']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      receiverName: json['receiverName']?.toString() ?? 'User',
      receiverPhone: json['receiverPhone']?.toString() ?? '',
    );
  }

  static String encodeList(List<SavedAddressModel> addresses) {
    return jsonEncode(addresses.map((a) => a.toJson()).toList());
  }

  static List<SavedAddressModel> decodeList(String jsonStr) {
    if (jsonStr.isEmpty) return [];
    try {
      final List decoded = jsonDecode(jsonStr);
      return decoded.map((e) => SavedAddressModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
