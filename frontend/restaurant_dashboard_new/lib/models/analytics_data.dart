class AnalyticsData {
  final double totalIncome;
  final int totalOrders;
  final int pendingOrders;
  final double pendingIncome;
  final double dailyIncome;
  final int dailyOrders;
  final List<OrderRate> orderRate;
  final List<PopularItem> popularItems;

  AnalyticsData({
    required this.totalIncome,
    required this.totalOrders,
    required this.pendingOrders,
    required this.pendingIncome,
    required this.dailyIncome,
    required this.dailyOrders,
    required this.orderRate,
    required this.popularItems,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    var orderRateList = json['order_rate'] as List;
    List<OrderRate> orderRateData = orderRateList.map((i) => OrderRate.fromJson(i)).toList();

    var popularItemsList = json['popular_items'] as List;
    List<PopularItem> popularItemsData = popularItemsList.map((i) => PopularItem.fromJson(i)).toList();

    return AnalyticsData(
      totalIncome: (json['total_income'] as num? ?? 0).toDouble(),
      totalOrders: json['total_orders'] as int? ?? 0,
      pendingOrders: json['pending_orders'] as int? ?? 0,
      pendingIncome: (json['pending_income'] as num? ?? 0).toDouble(),
      dailyIncome: (json['daily_income'] as num? ?? 0).toDouble(),
      dailyOrders: json['daily_orders'] as int? ?? 0,
      orderRate: orderRateData,
      popularItems: popularItemsData,
    );
  }
}

class OrderRate {
  final String month;
  final int orders;

  OrderRate({required this.month, required this.orders});

  factory OrderRate.fromJson(Map<String, dynamic> json) {
    return OrderRate(
      month: json['month'] as String,
      orders: json['orders'] as int,
    );
  }
}

class PopularItem {
  final String name;
  final int count;
  final String? image;

  PopularItem({required this.name, required this.count, this.image});

  factory PopularItem.fromJson(Map<String, dynamic> json) {
    return PopularItem(
      name: json['name'] as String,
      count: json['count'] as int,
      image: json['image'] as String?,
    );
  }
}
