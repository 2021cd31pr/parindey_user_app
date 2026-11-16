import 'cart_item_model.dart';

class OrderRequest {
  final String restaurantId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double? latitude;
  final double? longitude;
  final String paymentMethod;
  final double totalAmount;
  final List<CartItemModel> items;

  OrderRequest({
    required this.restaurantId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.latitude,
    this.longitude,
    this.paymentMethod = 'ONLINE',
    required this.totalAmount,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    final double lat = latitude ?? 22.7196;
    final double lng = longitude ?? 75.8577;

    return {
      'restaurantId': restaurantId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'deliveryLatitude': lat,
      'deliveryLongitude': lng,
      'latitude': lat,
      'longitude': lng,
      'deliveryLocation': {'lat': lat, 'lng': lng},
      'paymentMethod': paymentMethod,
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toOrderItemJson()).toList(),
    };
  }
}

class OrderResponse {
  final String id;
  final String restaurantId;
  final String? restaurantName;
  final String? restaurantAddress;
  final double? restaurantLatitude;
  final double? restaurantLongitude;
  final String status;
  final double totalAmount;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? assignedToAdminAt;
  final String? deliveryPartnerId;
  final String? deliveryPartnerName;
  final String? deliveryPartnerPhone;
  final String? assignedDeliveryAt;
  final String? deliveredAt;
  final String? createdAt;
  final List<dynamic>? items;

  OrderResponse({
    required this.id,
    required this.restaurantId,
    this.restaurantName,
    this.restaurantAddress,
    this.restaurantLatitude,
    this.restaurantLongitude,
    required this.status,
    required this.totalAmount,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.paymentMethod,
    this.paymentStatus,
    this.assignedToAdminAt,
    this.deliveryPartnerId,
    this.deliveryPartnerName,
    this.deliveryPartnerPhone,
    this.assignedDeliveryAt,
    this.deliveredAt,
    this.createdAt,
    this.items,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      id: json['id']?.toString() ?? json['orderId']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString() ?? json['restaurant']?['name']?.toString(),
      restaurantAddress: json['restaurantAddress']?.toString() ?? json['restaurant']?['address']?.toString(),
      restaurantLatitude: (json['restaurantLatitude'] as num?)?.toDouble(),
      restaurantLongitude: (json['restaurantLongitude'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'PLACED',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      deliveryAddress: json['deliveryAddress']?.toString() ?? '',
      deliveryLatitude: (json['deliveryLatitude'] as num?)?.toDouble() ?? (json['latitude'] as num?)?.toDouble(),
      deliveryLongitude: (json['deliveryLongitude'] as num?)?.toDouble() ?? (json['longitude'] as num?)?.toDouble(),
      paymentMethod: json['paymentMethod']?.toString() ?? 'ONLINE',
      paymentStatus: json['paymentStatus']?.toString() ?? 'PAID',
      assignedToAdminAt: json['assignedToAdminAt']?.toString(),
      deliveryPartnerId: json['deliveryPartnerId']?.toString(),
      deliveryPartnerName: json['deliveryPartnerName']?.toString() ?? json['deliveryBoyName']?.toString(),
      deliveryPartnerPhone: json['deliveryPartnerPhone']?.toString() ?? json['deliveryBoyPhone']?.toString(),
      assignedDeliveryAt: json['assignedDeliveryAt']?.toString(),
      deliveredAt: json['deliveredAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
      items: json['items'] as List<dynamic>?,
    );
  }
}
