class MenuItem {
  final int id;
  final String name;
  final String description;
  final double price;
  final bool isAvailable;
  final String? imageUrl;
  final int category;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.isAvailable = true,
    this.imageUrl,
    required this.category,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // Handle cases where the API might return a nested category object, just an ID, or a string name.
    final categoryData = json['category'];
    final int categoryId;
    if (categoryData is Map<String, dynamic>) {
      categoryId = categoryData['id'] as int;
    } else if (categoryData is int) {
      categoryId = categoryData;
    } else {
      // If category is a string (category name), use a default ID of 0
      // This handles the case where the API returns StringRelatedField
      categoryId = 0;
    }

    return MenuItem(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      price: double.parse(json['price'].toString()),
      isAvailable: json['is_available'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
      category: categoryId,
    );
  }
}
