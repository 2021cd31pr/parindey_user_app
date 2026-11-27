class AuthResponse {
  final String userId;
  final String phone;
  final String? fullName;
  final String role;
  final bool isNewUser;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresInMs;

  AuthResponse({
    required this.userId,
    required this.phone,
    this.fullName,
    required this.role,
    this.isNewUser = false,
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresInMs = 86400000,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json, {String? fallbackPhone}) {
    final phoneVal = json['phone']?.toString() ?? fallbackPhone ?? '';
    final isNew = json['isNewUser'] == true || json['newUser'] == true;
    final name = json['fullName']?.toString() ?? json['name']?.toString();

    return AuthResponse(
      userId: json['userId']?.toString() ?? json['id']?.toString() ?? '',
      phone: phoneVal,
      fullName: (name != null && name.trim().isNotEmpty && name != 'null') ? name.trim() : null,
      role: json['role']?.toString() ?? 'ROLE_CUSTOMER',
      isNewUser: isNew,
      accessToken: json['accessToken']?.toString() ?? json['token']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      tokenType: json['tokenType']?.toString() ?? 'Bearer',
      expiresInMs: (json['expiresInMs'] as num?)?.toInt() ?? 86400000,
    );
  }
}
