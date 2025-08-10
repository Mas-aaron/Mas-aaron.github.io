class OrderReview {
  final int id;
  final double rating;
  final String comment;
  final String? replyText;
  final DateTime? repliedAt;

  OrderReview({
    required this.id,
    required this.rating,
    required this.comment,
    this.replyText,
    this.repliedAt,
  });

  factory OrderReview.fromJson(Map<String, dynamic> json) {
    return OrderReview(
      id: json['id'],
      rating: double.tryParse(json['rating'].toString()) ?? 0.0,
      comment: json['comment'],
      replyText: json['reply_text'],
      repliedAt: json['replied_at'] != null ? DateTime.parse(json['replied_at']) : null,
    );
  }
}
