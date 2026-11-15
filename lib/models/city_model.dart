class CityModel {
  final String id;
  final String name;
  final String state;
  final bool active;

  CityModel({
    required this.id,
    required this.name,
    required this.state,
    required this.active,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'state': state,
    'active': active,
  };
}
