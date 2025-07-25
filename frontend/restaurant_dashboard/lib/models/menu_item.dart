class MenuItem {
  final int id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool availableBreakfast;
  final bool availableLunch;
  final bool availableDinner;
  final List<int> modifierGroupIds;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.availableBreakfast,
    required this.availableLunch,
    required this.availableDinner,
    required this.modifierGroupIds,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] ?? '',
      availableBreakfast: json['available_breakfast'] ?? false,
      availableLunch: json['available_lunch'] ?? false,
      availableDinner: json['available_dinner'] ?? false,
      modifierGroupIds: (json['modifier_groups'] as List?)?.map((mg) => mg['id'] as int).toList() ?? [],
    );
  }
}
