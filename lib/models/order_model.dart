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
  final String? restaurantPhone;
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
  final DateTime? assignedDeliveryAt;
  final DateTime? deliveredAt;
  final DateTime? createdAt;
  final List<dynamic>? items;

  // ⏱️ NEW TIMER & STATUS TRACKING FIELDS
  final int prepTimeMinutes;          
  final DateTime? prepEndsAt;         
  final int prepExtendedCount;        
  final DateTime? acceptedAt;         
  final DateTime? pickupArrivedAt;    
  final DateTime? pickedUpAt;         
  final int remainingPrepSeconds;     

  OrderResponse({
    required this.id,
    required this.restaurantId,
    this.restaurantName,
    this.restaurantAddress,
    this.restaurantPhone,
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
    this.prepTimeMinutes = 10,
    this.prepEndsAt,
    this.prepExtendedCount = 0,
    this.acceptedAt,
    this.pickupArrivedAt,
    this.pickedUpAt,
    this.remainingPrepSeconds = 0,
  });

  factory OrderResponse.fromJson(Map<String, dynamic> json) {
    return OrderResponse(
      id: json['id']?.toString() ?? json['orderId']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString() ?? json['restaurant']?['name']?.toString(),
      restaurantAddress: json['restaurantAddress']?.toString() ?? json['restaurant']?['address']?.toString(),
      restaurantPhone: json['restaurantPhone']?.toString(),
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
      assignedDeliveryAt: json['assignedDeliveryAt'] != null ? DateTime.tryParse(json['assignedDeliveryAt']) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.tryParse(json['deliveredAt']) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      items: json['items'] as List<dynamic>?,
      prepTimeMinutes: (json['prepTimeMinutes'] as num?)?.toInt() ?? 10,
      prepEndsAt: json['prepEndsAt'] != null ? DateTime.tryParse(json['prepEndsAt']) : null,
      prepExtendedCount: (json['prepExtendedCount'] as num?)?.toInt() ?? 0,
      acceptedAt: json['acceptedAt'] != null ? DateTime.tryParse(json['acceptedAt']) : null,
      pickupArrivedAt: json['pickupArrivedAt'] != null ? DateTime.tryParse(json['pickupArrivedAt']) : null,
      pickedUpAt: json['pickedUpAt'] != null ? DateTime.tryParse(json['pickedUpAt']) : null,
      remainingPrepSeconds: (json['remainingPrepSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
