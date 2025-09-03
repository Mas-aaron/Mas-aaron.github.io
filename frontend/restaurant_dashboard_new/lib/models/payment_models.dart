class PaymentPeriod {
  final int id;
  final String periodType;
  final DateTime startDate;
  final DateTime endDate;
  final int totalOrders;
  final double grossRevenue;
  final double platformFee;
  final double deliveryFee;
  final double taxAmount;
  final double adjustments;
  final double netPayout;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String grossRevenueUgx;
  final String netPayoutUgx;
  final String platformFeeUgx;

  PaymentPeriod({
    required this.id,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.totalOrders,
    required this.grossRevenue,
    required this.platformFee,
    required this.deliveryFee,
    required this.taxAmount,
    required this.adjustments,
    required this.netPayout,
    required this.status,
    required this.createdAt,
    this.paidAt,
    required this.grossRevenueUgx,
    required this.netPayoutUgx,
    required this.platformFeeUgx,
  });

  factory PaymentPeriod.fromJson(Map<String, dynamic> json) {
    return PaymentPeriod(
      id: json['id'],
      periodType: json['period_type'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      totalOrders: json['total_orders'],
      grossRevenue: double.parse(json['gross_revenue'].toString()),
      platformFee: double.parse(json['platform_fee'].toString()),
      deliveryFee: double.parse(json['delivery_fee'].toString()),
      taxAmount: double.parse(json['tax_amount'].toString()),
      adjustments: double.parse(json['adjustments'].toString()),
      netPayout: double.parse(json['net_payout'].toString()),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      grossRevenueUgx: json['gross_revenue_ugx'],
      netPayoutUgx: json['net_payout_ugx'],
      platformFeeUgx: json['platform_fee_ugx'],
    );
  }
}

class OrderPayment {
  final int id;
  final int orderId;
  final int paymentPeriodId;
  final String orderNumber;
  final DateTime orderDate;
  final String customerName;
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double platformCommission;
  final double taxAmount;
  final double tipAmount;
  final double adjustments;
  final double netPayout;
  final String paymentStatus;
  final DateTime createdAt;
  final String subtotalUgx;
  final String netPayoutUgx;
  final String platformCommissionUgx;
  final String deliveryFeeUgx;

  OrderPayment({
    required this.id,
    required this.orderId,
    required this.paymentPeriodId,
    required this.orderNumber,
    required this.orderDate,
    required this.customerName,
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.platformCommission,
    required this.taxAmount,
    required this.tipAmount,
    required this.adjustments,
    required this.netPayout,
    required this.paymentStatus,
    required this.createdAt,
    required this.subtotalUgx,
    required this.netPayoutUgx,
    required this.platformCommissionUgx,
    required this.deliveryFeeUgx,
  });

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    return OrderPayment(
      id: json['id'],
      orderId: json['order'],
      paymentPeriodId: json['payment_period'],
      orderNumber: json['order_number'],
      orderDate: DateTime.parse(json['order_date']),
      customerName: json['customer_name'],
      subtotal: double.parse(json['subtotal'].toString()),
      deliveryFee: double.parse(json['delivery_fee'].toString()),
      serviceFee: double.parse(json['service_fee'].toString()),
      platformCommission: double.parse(json['platform_commission'].toString()),
      taxAmount: double.parse(json['tax_amount'].toString()),
      tipAmount: double.parse(json['tip_amount'].toString()),
      adjustments: double.parse(json['adjustments'].toString()),
      netPayout: double.parse(json['net_payout'].toString()),
      paymentStatus: json['payment_status'],
      createdAt: DateTime.parse(json['created_at']),
      subtotalUgx: json['subtotal_ugx'],
      netPayoutUgx: json['net_payout_ugx'],
      platformCommissionUgx: json['platform_commission_ugx'],
      deliveryFeeUgx: json['delivery_fee_ugx'],
    );
  }
}

class BankAccount {
  final int id;
  final String accountHolderName;
  final String bankName;
  final String accountType;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  BankAccount({
    required this.id,
    required this.accountHolderName,
    required this.bankName,
    required this.accountType,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'],
      accountHolderName: json['account_holder_name'],
      bankName: json['bank_name'],
      accountType: json['account_type'],
      isVerified: json['is_verified'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class PaymentDispute {
  final int id;
  final String disputeType;
  final String reason;
  final double amountDisputed;
  final String status;
  final String? restaurantResponse;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String orderNumber;
  final String amountDisputedUgx;

  PaymentDispute({
    required this.id,
    required this.disputeType,
    required this.reason,
    required this.amountDisputed,
    required this.status,
    this.restaurantResponse,
    this.resolutionNotes,
    required this.createdAt,
    this.resolvedAt,
    required this.orderNumber,
    required this.amountDisputedUgx,
  });

  factory PaymentDispute.fromJson(Map<String, dynamic> json) {
    return PaymentDispute(
      id: json['id'],
      disputeType: json['dispute_type'],
      reason: json['reason'],
      amountDisputed: double.parse(json['amount_disputed'].toString()),
      status: json['status'],
      restaurantResponse: json['restaurant_response'],
      resolutionNotes: json['resolution_notes'],
      createdAt: DateTime.parse(json['created_at']),
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at']) : null,
      orderNumber: json['order_number'],
      amountDisputedUgx: json['amount_disputed_ugx'],
    );
  }
}
