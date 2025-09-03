class Order {
  final int id;
  final String restaurantName;
  final String deliveryAddress;
  final String status;
  final double totalPrice;
  final double? restaurantLat;
  final double? restaurantLng;
  final double? customerLat;
  final double? customerLng;
  final String? customerName;
  final String? customerPhone;

  Order({
    required this.id,
    required this.restaurantName,
    required this.deliveryAddress,
    required this.status,
    required this.totalPrice,
    this.restaurantLat,
    this.restaurantLng,
    this.customerLat,
    this.customerLng,
    this.customerName,
    this.customerPhone,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      restaurantName: json['restaurant_name'] ?? 'Unknown Restaurant',
      deliveryAddress: json['delivery_address'],
      status: json['status'],
      totalPrice: double.parse(json['total_price']),
      restaurantLat: json['restaurant_lat'] as double?,
      restaurantLng: json['restaurant_lng'] as double?,
      customerLat: json['customer_lat'] as double?,
      customerLng: json['customer_lng'] as double?,
      customerName: json['customer']?['first_name'] != null && json['customer']?['last_name'] != null 
          ? '${json['customer']['first_name']} ${json['customer']['last_name']}'
          : null,
      customerPhone: json['customer']?['phone_number'],
    );
  }
}
