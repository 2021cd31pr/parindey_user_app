class CartItemModel {
  final String dishId;
  final String dishName;
  final int quantity;
  final double unitPrice;
  final bool isVeg;
  final String? imageUrl;
  final String restaurantId;

  CartItemModel({
    required this.dishId,
    required this.dishName,
    required this.quantity,
    required this.unitPrice,
    this.isVeg = true,
    this.imageUrl,
    required this.restaurantId,
  });

  double get totalPrice => quantity * unitPrice;

  CartItemModel copyWith({int? quantity}) {
    return CartItemModel(
      dishId: dishId,
      dishName: dishName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      isVeg: isVeg,
      imageUrl: imageUrl,
      restaurantId: restaurantId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dishId': dishId,
      'dishName': dishName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'isVeg': isVeg,
      'imageUrl': imageUrl,
      'restaurantId': restaurantId,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      dishId: json['dishId']?.toString() ?? '',
      dishName: json['dishName']?.toString() ?? 'Dish',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      isVeg: json['isVeg'] as bool? ?? true,
      imageUrl: json['imageUrl']?.toString(),
      restaurantId: json['restaurantId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toOrderItemJson() {
    return {
      'dishId': dishId,
      'dishName': dishName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}
