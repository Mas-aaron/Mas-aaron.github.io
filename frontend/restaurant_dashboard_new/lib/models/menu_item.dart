class MenuItem {
  final int id;
  final String name;
  final String description;
  final double price;
  final bool isAvailable;
  final String? image;
  final int category;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.isAvailable = true,
    this.image,
    required this.category,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: double.parse(json['price'].toString()),
      isAvailable: json['is_available'] ?? true,
      image: json['image'],
      category: json['category'],
    );
  }
}
