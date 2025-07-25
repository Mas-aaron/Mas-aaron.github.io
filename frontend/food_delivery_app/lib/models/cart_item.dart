import 'package:food_delivery_app/models/menu_item.dart';

class CartItem {
  final int id;
  final MenuItem menuItem;
  final int quantity;

  CartItem({
    required this.id,
    required this.menuItem,
    required this.quantity,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      menuItem: MenuItem.fromJson(json['menu_item']),
      quantity: json['quantity'],
    );
  }
}
