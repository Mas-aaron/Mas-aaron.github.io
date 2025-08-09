import 'package:restaurant_dashboard_new/models/order_item.dart';
import 'package:restaurant_dashboard_new/models/user.dart';

class Order {
  final int id;
  final String status;
  final double totalPrice;
  final String createdAt;
  final String deliveryAddress;
  final List<OrderItem> items;
  final User? user;

  String get customerName => user?.username ?? 'N/A';

  Order({
    required this.id,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    required this.deliveryAddress,
    required this.items,
    this.user,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List? ?? [];
    List<OrderItem> items = itemsList.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      id: json['id'],
      status: json['status'] ?? 'Unknown',
      totalPrice: (json['total_price'] is String)
          ? (double.tryParse(json['total_price']) ?? 0.0)
          : (json['total_price'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] ?? '',
      deliveryAddress: json['delivery_address'] ?? 'No address',
      items: items,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}

