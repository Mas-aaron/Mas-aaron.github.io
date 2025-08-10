class Bill {
  final int id;
  final double amount;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;

  Bill({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'],
      amount: double.parse(json['amount']),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
    );
  }
}
