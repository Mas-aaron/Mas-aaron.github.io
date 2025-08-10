class RiderReview {
  final int id;
  final int orderId;
  final String customerName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  RiderReview({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory RiderReview.fromJson(Map<String, dynamic> json) {
    return RiderReview(
      id: json['id'],
      orderId: json['order'],
      customerName: json['customer_name'] ?? 'Anonymous',
      rating: double.parse(json['rating'].toString()),
      comment: json['comment'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
