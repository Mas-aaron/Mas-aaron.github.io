import 'package:food_delivery_app/models/order_item.dart';
import 'package:food_delivery_app/models/restaurant.dart';

class Order {
  final int id;
  final String totalPrice;
  final String status;
  final String createdAt;
  final Restaurant restaurant;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.restaurant,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsFromJson = json['items'] as List? ?? [];
    List<OrderItem> itemsList = itemsFromJson.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      id: json['id'] ?? 0,
      totalPrice: json['total_price'] ?? '0.00',
      status: json['status'] ?? 'Unknown',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      restaurant: Restaurant.fromJson(json['restaurant'] ?? {}),
      deliveryAddress: json['delivery_address'] ?? 'No address provided',
      deliveryLat: double.tryParse(json['delivery_lat']?.toString() ?? '0.0') ?? 0.0,
      deliveryLng: double.tryParse(json['delivery_lng']?.toString() ?? '0.0') ?? 0.0,
      items: itemsList,
    );
  }
}
