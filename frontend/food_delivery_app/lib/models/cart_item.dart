import 'package:food_delivery_app/models/menu_item.dart';

class CartItem {
  final int id;
  final int quantity;
  final MenuItem? menuItem;

  CartItem({
    required this.id,
    required this.quantity,
    this.menuItem,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      quantity: json['quantity'],
      menuItem: json['menu_item'] != null
          ? MenuItem.fromJson(json['menu_item'])
          : null,
    );
  }

  double get price => (menuItem?.price ?? 0.0) * quantity;
}
