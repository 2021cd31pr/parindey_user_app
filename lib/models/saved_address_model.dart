import 'dart:convert';

class SavedAddressModel {
  final String id;
  final String userId;
  final String label; // 'HOME', 'WORK', 'OTHER'
  final String houseFlatNo;
  final String landmark;
  final String fullAddress;
  final double? latitude;
  final double? longitude;
  final String receiverName;
  final String receiverPhone;
  final bool isDefault;

  SavedAddressModel({
    required this.id,
    this.userId = '',
    this.label = 'HOME',
    required this.houseFlatNo,
    required this.landmark,
    required this.fullAddress,
    this.latitude,
    this.longitude,
    required this.receiverName,
    required this.receiverPhone,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'label': label,
      'houseFlatNo': houseFlatNo,
      'landmark': landmark,
      'fullAddress': fullAddress,
      'latitude': latitude,
      'longitude': longitude,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'isDefault': isDefault,
    };
  }

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      label: json['label']?.toString() ?? 'HOME',
      houseFlatNo: json['houseFlatNo']?.toString() ?? json['houseNo']?.toString() ?? '',
      landmark: json['landmark']?.toString() ?? '',
      fullAddress: json['fullAddress']?.toString() ?? json['streetArea']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      receiverName: json['receiverName']?.toString() ?? 'User',
      receiverPhone: json['receiverPhone']?.toString() ?? '',
      isDefault: json['isDefault'] == true,
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

