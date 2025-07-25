import 'package:food_delivery_app/models/menu_item.dart';

class OrderItem {
  final int id;
  final MenuItem menuItem;
  final int quantity;
  final String price;

  OrderItem({
    required this.id,
    required this.menuItem,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      menuItem: MenuItem.fromJson(json['menu_item']),
      quantity: json['quantity'],
      price: json['price'],
    );
  }
}
