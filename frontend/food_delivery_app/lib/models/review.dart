class Review {
  final int id;
  final String user;
  final int menuItemId;
  final double rating;
  final String comment;
  final String createdAt;

  Review({
    required this.id,
    required this.user,
    required this.menuItemId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      user: json['user'] as String,
      menuItemId: json['menu_item'] as int,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}
