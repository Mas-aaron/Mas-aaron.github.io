import 'package:food_delivery_app/models/order_item.dart';
import 'package:food_delivery_app/models/order_review.dart';
import 'package:food_delivery_app/models/restaurant.dart';

class Order {
  final int id;
  final int? riderId;
  final String totalPrice;
  final String status;
  final String createdAt;
  final Restaurant restaurant;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final List<OrderItem> items;
  final OrderReview? review;

  Order({
    required this.id,
    this.riderId,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.restaurant,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.items,
    this.review,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsFromJson = json['items'] as List? ?? [];
    List<OrderItem> itemsList = itemsFromJson.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      id: json['id'] ?? 0,
      riderId: json['rider_id'],
      totalPrice: json['total_price'] ?? '0.00',
      status: json['status'] ?? 'Unknown',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      restaurant: Restaurant.fromJson(json['restaurant'] ?? {}),
      deliveryAddress: json['delivery_address'] ?? 'No address provided',
      deliveryLat: double.tryParse(json['delivery_lat']?.toString() ?? '0.0') ?? 0.0,
      deliveryLng: double.tryParse(json['delivery_lng']?.toString() ?? '0.0') ?? 0.0,
      items: itemsList,
      review: json['review'] != null ? OrderReview.fromJson(json['review']) : null,
    );
  }

  Order copyWith({
    int? id,
    int? riderId,
    String? totalPrice,
    String? status,
    String? createdAt,
    Restaurant? restaurant,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    List<OrderItem>? items,
    OrderReview? review,
  }) {
    return Order(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      restaurant: restaurant ?? this.restaurant,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLng: deliveryLng ?? this.deliveryLng,
      items: items ?? this.items,
      review: review ?? this.review,
    );
  }
}
