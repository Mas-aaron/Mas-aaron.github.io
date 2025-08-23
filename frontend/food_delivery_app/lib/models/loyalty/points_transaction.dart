class PointsTransaction {
  final int points;
  final String transactionType;
  final String description;
  final DateTime createdAt;

  PointsTransaction({
    required this.points,
    required this.transactionType,
    required this.description,
    required this.createdAt,
  });

  factory PointsTransaction.fromJson(Map<String, dynamic> json) {
    return PointsTransaction(
      points: json['points'],
      transactionType: json['transaction_type'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
