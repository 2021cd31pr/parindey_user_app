class ComboModel {
  final String id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;

  ComboModel({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
  });

  factory ComboModel.fromJson(Map<String, dynamic> json) {
    return ComboModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? (json['basePrice'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
    );
  }
}
