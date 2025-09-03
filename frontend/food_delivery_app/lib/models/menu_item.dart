class MenuItem {
  final int id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final dynamic restaurant; // Can be int or Restaurant object
  final dynamic category; // Can be int or string (category name)
  final bool availableBreakfast;
  final bool availableLunch;
  final bool availableDinner;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.restaurant,
    required this.category,
    required this.availableBreakfast,
    required this.availableLunch,
    required this.availableDinner,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Item',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'] ?? json['image'],
      restaurant: json['restaurant'], // Accept any type (int, object, etc.)
      category: json['category'], // Accept any type (int, string, etc.)
      availableBreakfast: json['available_breakfast'] ?? false,
      availableLunch: json['available_lunch'] ?? false,
      availableDinner: json['available_dinner'] ?? false,
    );
  }
}
