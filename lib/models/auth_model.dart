class AuthResponse {
  final String userId;
  final String phone;
  final String role;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresInMs;

  AuthResponse({
    required this.userId,
    required this.phone,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresInMs = 86400000,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json, {String? fallbackPhone}) {
    final phoneVal = json['phone']?.toString() ?? fallbackPhone ?? '';
    return AuthResponse(
      userId: json['userId']?.toString() ?? json['id']?.toString() ?? '',
      phone: phoneVal,
      role: json['role']?.toString() ?? 'ROLE_CUSTOMER',
      accessToken: json['accessToken']?.toString() ?? json['token']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      tokenType: json['tokenType']?.toString() ?? 'Bearer',
      expiresInMs: (json['expiresInMs'] as num?)?.toInt() ?? 86400000,
    );
  }
}
