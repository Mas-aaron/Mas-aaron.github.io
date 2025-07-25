import 'package:food_delivery_app/models/cart_item.dart';

class Cart {
  final int id;
  final List<CartItem> items;
  final String createdAt;

  Cart({
    required this.id,
    required this.items,
    required this.createdAt,
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List;
    List<CartItem> cartItems = itemsList.map((i) => CartItem.fromJson(i)).toList();

    return Cart(
      id: json['id'],
      items: cartItems,
      createdAt: json['created_at'],
    );
  }
}
