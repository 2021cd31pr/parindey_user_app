class DishModel {
  final String id;
  final String name;
  final double price;
  final double? originalPrice;
  final double? discountPercentage;
  final bool isVeg;
  final String? description;
  final String? imageUrl;
  final String? categoryName;
  final String? categoryId;
  final String? restaurantId;
  final String? restaurantName;
  final String? discountBadge;
  final bool available;
  final int? ordersCount;

  DishModel({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice,
    this.discountPercentage,
    this.isVeg = true,
    this.description,
    this.imageUrl,
    this.categoryName,
    this.categoryId,
    this.restaurantId,
    this.restaurantName,
    this.discountBadge,
    this.available = true,
    this.ordersCount,
  });

  static String? _parseImageUrl(dynamic url) {
    if (url == null) return null;
    final str = url.toString().trim();
    if (str.isEmpty || str == 'null' || str == 'undefined') return null;
    if (str.startsWith('/')) {
      return 'https://parindey-92zk.onrender.com$str';
    }
    return str;
  }

  factory DishModel.fromJson(Map<String, dynamic> json) {
    double priceVal = (json['price'] as num?)?.toDouble() ??
        (json['unitPrice'] as num?)?.toDouble() ??
        (json['basePrice'] as num?)?.toDouble() ??
        0.0;

    double? origPrice = (json['originalPrice'] as num?)?.toDouble();
    double? discPct = (json['discountPercentage'] as num?)?.toDouble();

    bool isVegVal = true;
    if (json.containsKey('isVeg')) {
      isVegVal = json['isVeg'] as bool? ?? true;
    } else if (json.containsKey('veg')) {
      isVegVal = json['veg'] as bool? ?? true;
    } else if (json.containsKey('foodType')) {
      isVegVal = json['foodType']?.toString().toUpperCase() == 'VEG';
    } else if (json.containsKey('type')) {
      isVegVal = json['type']?.toString().toUpperCase() == 'VEG';
    }

    String? badge;
    if (discPct != null && discPct > 0) {
      badge = '${discPct.toStringAsFixed(0)}% OFF';
    } else if (json['discount'] != null) {
      badge = '${json['discount']}';
    }

    return DishModel(
      id: json['id']?.toString() ?? json['dishId']?.toString() ?? '',
      name: json['name']?.toString() ?? json['dishName']?.toString() ?? '',
      price: priceVal,
      originalPrice: origPrice,
      discountPercentage: discPct,
      isVeg: isVegVal,
      description: json['description']?.toString(),
      imageUrl: _parseImageUrl(json['imageUrl'] ?? json['image'] ?? json['photo'] ?? json['picture']),
      categoryName: json['categoryName']?.toString() ?? json['category']?.toString(),
      categoryId: json['categoryId']?.toString(),
      restaurantId: json['restaurantId']?.toString(),
      restaurantName: json['restaurantName']?.toString(),
      discountBadge: badge,
      available: json['available'] as bool? ?? true,
      ordersCount: (json['ordersCount'] as num?)?.toInt(),
    );
  }
}
