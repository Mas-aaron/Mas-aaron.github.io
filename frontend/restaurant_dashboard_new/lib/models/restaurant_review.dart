class RestaurantReview {
  final int id;
  final int orderId;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String? replyText;
  final DateTime? repliedAt;
  final String customerName;
  final double orderTotal;
  final int orderItemsCount;

  RestaurantReview({
    required this.id,
    required this.orderId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.replyText,
    this.repliedAt,
    required this.customerName,
    required this.orderTotal,
    required this.orderItemsCount,
  });

  factory RestaurantReview.fromJson(Map<String, dynamic> json) {
    return RestaurantReview(
      id: json['id'],
      orderId: json['order'],
      rating: double.tryParse(json['rating']?.toString() ?? '0.0') ?? 0.0,
      comment: json['comment'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      replyText: json['reply_text'],
      repliedAt: json['replied_at'] != null ? DateTime.parse(json['replied_at']) : null,
      customerName: json['customer_name'] ?? 'Anonymous',
      orderTotal: double.tryParse(json['order_total']?.toString() ?? '0.0') ?? 0.0,
      orderItemsCount: json['order_items_count'] ?? 0,
    );
  }
}
