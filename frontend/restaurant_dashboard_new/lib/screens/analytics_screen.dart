import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:restaurant_dashboard_new/models/analytics_data.dart';
import 'package:restaurant_dashboard_new/services/analytics_service.dart';
import 'package:restaurant_dashboard_new/utils/currency_formatter.dart';
import 'package:restaurant_dashboard_new/utils/responsive.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  AnalyticsData? _analyticsData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    try {
      final data = await _analyticsService.getAnalyticsData();
      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Failed to load analytics. Please check your connection and ensure the server is running.\n\nError: $_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_analyticsData == null) {
      return const Center(child: Text('No analytics data available.'));
    }

    return Container(
      color: const Color(0xFFF7F7F7),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Responsive(
          mobile: _buildMobileLayout(_analyticsData!),
          desktop: _buildDesktopLayout(_analyticsData!),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(AnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMobileHeader(data),
        const SizedBox(height: 24),
        _buildPositiveReviewCard(data),
        const SizedBox(height: 24),
        _buildCategorySection(),
        const SizedBox(height: 24),
        _buildPopularDishesSection(data),
      ],
    );
  }

  Widget _buildMobileHeader(AnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dashboard Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildMobileRevenueCards(data),
      ],
    );
  }

  Widget _buildMobileRevenueCards(AnalyticsData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCompactInfoCard(
                'Total Revenue',
                CurrencyFormatter.formatUGX(data.totalIncome),
                Icons.trending_up,
                const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactInfoCard(
                'Pending Revenue',
                CurrencyFormatter.formatUGX(data.pendingIncome),
                Icons.hourglass_top,
                const LinearGradient(
                  colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCompactInfoCard(
                'Today\'s Revenue',
                CurrencyFormatter.formatUGX(data.dailyIncome),
                Icons.today,
                const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactInfoCard(
                'Total Orders',
                data.totalOrders.toString(),
                Icons.receipt_long,
                const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactInfoCard(String title, String value, IconData icon, LinearGradient gradient) {
    return Container(
      height: 85, // Increased height to prevent overflow
      padding: const EdgeInsets.all(8), // Reduced padding
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14, // Reduced font size
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 9, // Reduced font size
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(AnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(data),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildPositiveReviewCard(data),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildCategorySection(),
        const SizedBox(height: 24),
        _buildPopularDishesSection(data),
      ],
    );
  }

  Widget _buildHeader(AnalyticsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dashboard Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildRevenueCardsRow(data),
      ],
    );
  }

  Widget _buildRevenueCardsRow(AnalyticsData data) {
    return Container(
      height: 120,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 200,
              child: _buildModernInfoCard(
                'Total Revenue',
                CurrencyFormatter.formatUGX(data.totalIncome),
                Icons.trending_up,
                const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                '+12.5%',
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 200,
              child: _buildModernInfoCard(
                'Pending Revenue',
                CurrencyFormatter.formatUGX(data.pendingIncome),
                Icons.hourglass_top,
                const LinearGradient(
                  colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                '${data.pendingOrders} orders',
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 200,
              child: _buildModernInfoCard(
                'Today\'s Revenue',
                CurrencyFormatter.formatUGX(data.dailyIncome),
                Icons.today,
                const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                '${data.dailyOrders} orders',
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 200,
              child: _buildModernInfoCard(
                'Total Orders',
                data.totalOrders.toString(),
                Icons.receipt_long,
                const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                'All time',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInfoCard(String title, String value, IconData icon, LinearGradient gradient, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important to keep the column from expanding infinitely
          children: [
            const SizedBox(height: 12), // More space at the top
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositiveReviewCard(AnalyticsData data) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Order Rate', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: data.orderRate.isEmpty
                ? Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No order data yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start receiving orders to see analytics',
                          style: TextStyle(color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: data.orderRate.isEmpty
                          ? 0
                          : (data.orderRate.map((e) => e.orders).reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value.toInt() >= data.orderRate.length) return const SizedBox();
                              final month = data.orderRate[value.toInt()].month;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(month, style: const TextStyle(fontSize: 12)),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: _getBarGroups(data.orderRate),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _getBarGroups(List<OrderRate> orderRates) {
    if (orderRates.isEmpty) {
      return [];
    }
    return orderRates.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: data.orders.toDouble(),
            color: Colors.blue.shade300,
            width: 15,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildCategorySection() {
    final categories = [
      {'icon': Icons.restaurant_menu, 'label': 'All', 'color': const Color(0xFF4CAF50)},
      {'icon': Icons.local_pizza, 'label': 'Pizza', 'color': const Color(0xFFFF5722)},
      {'icon': Icons.cake, 'label': 'Dessert', 'color': const Color(0xFFE91E63)},
      {'icon': Icons.local_cafe, 'label': 'Drink', 'color': const Color(0xFF2196F3)},
      {'icon': Icons.ramen_dining, 'label': 'Asian', 'color': const Color(0xFFFF9800)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category, color: Color(0xFF4CAF50), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Food Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 5 : 3,
              childAspectRatio: 1.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return _buildModernCategoryItem(
                categories[index]['icon'] as IconData,
                categories[index]['label'] as String,
                categories[index]['color'] as Color,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernCategoryItem(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularDishesSection(AnalyticsData data) {
    if (data.popularItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star, color: Color(0xFFFF9800), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Popular Dishes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Responsive(
            mobile: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.popularItems.length,
              itemBuilder: (context, index) {
                final dish = data.popularItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildModernPopularDishItem(dish),
                );
              },
            ),
            desktop: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: data.popularItems.length,
              itemBuilder: (context, index) {
                final dish = data.popularItems[index];
                return _buildModernPopularDishItem(dish);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPopularDishItem(PopularItem dish) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.orange[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: dish.image != null
                    ? Image.network(
                        dish.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.fastfood, color: Colors.orange[600], size: 24);
                        },
                      )
                    : Icon(Icons.fastfood, color: Colors.orange[600], size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${dish.count} orders',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.trending_up, color: Colors.orange[600], size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountVoucherCard() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Get Discount Voucher\nUp To 20%',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Image.network(
              'https://i.pravatar.cc/250?img=32', // Placeholder image
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.card_giftcard, color: Colors.grey, size: 80);
              },
            ),
          ),
        ],
      ),
    );
  }
}
