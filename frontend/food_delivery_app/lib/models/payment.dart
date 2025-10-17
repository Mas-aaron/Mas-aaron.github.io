enum PaymentMethod {
  cashOnDelivery,
  mtnMobileMoney,
  airtelMoney,
  pesapal,
}

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

class Payment {
  final int? id;
  final String orderId;
  final PaymentMethod method;
  final double amount;
  final PaymentStatus status;
  final String? phoneNumber;
  final String? transactionId;
  final String? reference;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? failureReason;

  Payment({
    this.id,
    required this.orderId,
    required this.method,
    required this.amount,
    required this.status,
    this.phoneNumber,
    this.transactionId,
    this.reference,
    required this.createdAt,
    this.updatedAt,
    this.failureReason,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      orderId: json['order_id']?.toString() ?? '',
      method: _parsePaymentMethod(json['method']),
      amount: double.parse(json['amount']?.toString() ?? '0'),
      status: _parsePaymentStatus(json['status']),
      phoneNumber: json['phone_number'],
      transactionId: json['transaction_id'],
      reference: json['reference'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      failureReason: json['failure_reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'method': _paymentMethodToString(method),
      'amount': amount.toString(),
      'phone_number': phoneNumber,
      'reference': reference,
    };
  }

  static PaymentMethod _parsePaymentMethod(String? method) {
    switch (method?.toLowerCase()) {
      case 'mtn_mobile_money':
        return PaymentMethod.mtnMobileMoney;
      case 'airtel_money':
        return PaymentMethod.airtelMoney;
      case 'pesapal':
        return PaymentMethod.pesapal;
      case 'cash_on_delivery':
      default:
        return PaymentMethod.cashOnDelivery;
    }
  }

  static PaymentStatus _parsePaymentStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'processing':
        return PaymentStatus.processing;
      case 'completed':
        return PaymentStatus.completed;
      case 'failed':
        return PaymentStatus.failed;
      case 'cancelled':
        return PaymentStatus.cancelled;
      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }

  static String _paymentMethodToString(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.mtnMobileMoney:
        return 'mtn_mobile_money';
      case PaymentMethod.airtelMoney:
        return 'airtel_money';
      case PaymentMethod.cashOnDelivery:
        return 'cash_on_delivery';
      case PaymentMethod.pesapal:
        return 'pesapal';
    }
  }

  String get methodDisplayName {
    switch (method) {
      case PaymentMethod.mtnMobileMoney:
        return 'MTN Mobile Money';
      case PaymentMethod.airtelMoney:
        return 'Airtel Money';
      case PaymentMethod.cashOnDelivery:
        return 'Cash on Delivery';
      case PaymentMethod.pesapal:
        return 'Pesapal Payment';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }
}
