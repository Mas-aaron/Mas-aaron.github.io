class OrderItem {
  final int id;
  final String menuItemName;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    required this.menuItemName,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int,
      menuItemName: json['menu_item_name'] as String? ?? 'Unknown Item',
      quantity: json['quantity'] as int,
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}
