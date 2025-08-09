class MenuItem {
  final int id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final int restaurant;
  final int category;
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
      id: json['id'],
      name: json['name'] ?? 'Unknown Item',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'] ?? json['image'],
      restaurant: json['restaurant'] ?? 0,
      category: json['category'] ?? 0,
      availableBreakfast: json['available_breakfast'] ?? false,
      availableLunch: json['available_lunch'] ?? false,
      availableDinner: json['available_dinner'] ?? false,
    );
  }
}
