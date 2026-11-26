class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int? displayOrder;
  final bool active;

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.displayOrder,
    this.active = true,
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

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['categoryName']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: _parseImageUrl(json['imageUrl'] ?? json['image']),
      displayOrder: (json['displayOrder'] as num?)?.toInt(),
      active: json['active'] as bool? ?? true,
    );
  }
}
