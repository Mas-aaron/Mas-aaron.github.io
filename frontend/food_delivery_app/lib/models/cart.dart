import 'package:food_delivery_app/models/cart_item.dart';

class Cart {
  final int id;
  final List<CartItem> items;

  Cart({
    required this.id,
    required this.items,
  });

  double get totalPrice {
    return items.fold(0.0, (sum, item) => sum + item.price);
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<CartItem> cartItems = [];

    for (var itemJson in itemsList) {
      try {
        cartItems.add(CartItem.fromJson(itemJson));
      } catch (e) {
        print('Failed to parse CartItem: $e');
        // Optionally, skip the item or handle the error as needed
      }
    }

    return Cart(
      id: json['id'],
      items: cartItems,
    );
  }
}
