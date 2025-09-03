import 'package:restaurant_dashboard_new/models/order_item.dart';
import 'package:restaurant_dashboard_new/models/user.dart';

class Order {
  final int id;
  final String status;
  final double totalPrice;
  final String createdAt;
  final String? deliveryAddress;
  final List<OrderItem> items;
  final User? user;
  final String? orderType;
  final String? scheduledTime;
  final double? tipAmount;
  final String? tableNumber;
  final int? estimatedPrepTime;

  String get customerName => user?.username ?? 'N/A';

  Order({
    required this.id,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    this.deliveryAddress,
    required this.items,
    this.user,
    this.orderType,
    this.scheduledTime,
    this.tipAmount,
    this.tableNumber,
    this.estimatedPrepTime,
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
      deliveryAddress: json['delivery_address'],
      items: items,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      orderType: json['order_type'],
      scheduledTime: json['scheduled_time'],
      tipAmount: (json['tip_amount'] as num?)?.toDouble(),
      tableNumber: json['table_number'],
      estimatedPrepTime: json['estimated_prep_time'],
    );
  }
}

