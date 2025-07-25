import 'package:food_delivery_app/models/order_item.dart';
import 'package:food_delivery_app/models/restaurant.dart';

class Order {
  final int id;
  final Restaurant restaurant;
  final String totalPrice;
  final String status;
  final String createdAt;
  final String deliveryAddress;
  final List<OrderItem> items;
  final double? restaurantLat;
  final double? restaurantLng;
  final double? customerLat;
  final double? customerLng;

  Order({
    required this.id,
    required this.restaurant,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.deliveryAddress,
    required this.items,
    this.restaurantLat,
    this.restaurantLng,
    this.customerLat,
    this.customerLng,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List;
    List<OrderItem> orderItems = itemsList.map((i) => OrderItem.fromJson(i)).toList();

    return Order(
      id: json['id'],
      restaurant: Restaurant.fromJson(json['restaurant']),
      totalPrice: json['total_price'],
      status: json['status'],
      createdAt: json['created_at'],
      deliveryAddress: json['delivery_address'],
      items: orderItems,
      restaurantLat: json['restaurant_lat'] != null ? double.parse(json['restaurant_lat'].toString()) : null,
      restaurantLng: json['restaurant_lng'] != null ? double.parse(json['restaurant_lng'].toString()) : null,
      customerLat: json['customer_lat'] != null ? double.parse(json['customer_lat'].toString()) : null,
      customerLng: json['customer_lng'] != null ? double.parse(json['customer_lng'].toString()) : null,
    );
  }
}
