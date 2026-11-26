class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final String? cityId;
  final double rating;
  final double? costForTwo;
  final String? imageUrl;
  final String? licenseNumber;
  final bool active;
  final String? cuisine;
  final String deliveryTime;
  final String distance;
  final String? description;
  final double? latitude;
  final double? longitude;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    this.cityId,
    this.rating = 4.3,
    this.costForTwo,
    this.imageUrl,
    this.licenseNumber,
    this.active = true,
    this.cuisine,
    this.deliveryTime = '30-35 mins',
    this.distance = '2.5 km',
    this.description,
    this.latitude,
    this.longitude,
  });

  static String? _parseImageUrl(dynamic url) {
    if (url == null) return null;
    final str = url.toString().trim();
    if (str.isEmpty || str == 'null' || str == 'undefined') return null;
    if (str.startsWith('/')) {
      return 'https://parindey-production.up.railway.app$str';
    }
    return str;
  }

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    double ratingVal = (json['rating'] as num?)?.toDouble() ??
        (json['averageRating'] as num?)?.toDouble() ??
        4.3;

    double? costForTwoVal = (json['costForTwo'] as num?)?.toDouble() ??
        (json['priceForTwo'] as num?)?.toDouble() ??
        (json['avgCost'] as num?)?.toDouble();

    String? cuisineVal;
    if (json['cuisine'] != null && json['cuisine'].toString().trim().isNotEmpty) {
      cuisineVal = json['cuisine'].toString().trim();
    } else if (json['cuisines'] != null && json['cuisines'].toString().trim().isNotEmpty) {
      cuisineVal = json['cuisines'].toString().trim();
    } else if (json['category'] != null && json['category'].toString().trim().isNotEmpty) {
      cuisineVal = json['category'].toString().trim();
    }

    String deliveryTimeVal = json['deliveryTime']?.toString() ??
        json['estimatedTime']?.toString() ??
        '30-35 mins';

    String distanceVal = json['distance']?.toString() ?? '2.5 km';

    String? descVal = json['description']?.toString() ??
        json['bio']?.toString() ??
        json['about']?.toString() ??
        json['details']?.toString();

    double? latVal = (json['latitude'] as num?)?.toDouble() ??
        (json['lat'] as num?)?.toDouble() ??
        (json['location']?['lat'] as num?)?.toDouble();

    double? lngVal = (json['longitude'] as num?)?.toDouble() ??
        (json['lng'] as num?)?.toDouble() ??
        (json['location']?['lng'] as num?)?.toDouble();

    return RestaurantModel(
      id: json['id']?.toString() ?? json['restaurantId']?.toString() ?? '',
      name: json['name']?.toString() ?? json['restaurantName']?.toString() ?? 'Unnamed Restaurant',
      address: json['address']?.toString() ?? json['location']?.toString() ?? 'Main Street',
      cityId: json['cityId']?.toString(),
      rating: ratingVal,
      costForTwo: costForTwoVal,
      imageUrl: _parseImageUrl(json['imageUrl'] ?? json['image'] ?? json['photo'] ?? json['logo'] ?? json['bannerUrl'] ?? json['bannerImage']),
      licenseNumber: json['licenseNumber']?.toString() ?? json['fssaiLicenseNumber']?.toString(),
      active: json['active'] as bool? ?? true,
      cuisine: cuisineVal,
      deliveryTime: deliveryTimeVal,
      distance: distanceVal,
      description: descVal,
      latitude: latVal,
      longitude: lngVal,
    );
  }
}
