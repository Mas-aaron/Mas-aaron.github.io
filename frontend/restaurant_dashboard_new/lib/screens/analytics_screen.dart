import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:restaurant_dashboard_new/models/analytics_data.dart';
import 'package:restaurant_dashboard_new/services/analytics_service.dart';
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
        _buildHeader(data),
        const SizedBox(height: 24),
        _buildPositiveReviewCard(data),
        const SizedBox(height: 24),
        _buildDiscountVoucherCard(),
        const SizedBox(height: 24),
        _buildCategorySection(),
        const SizedBox(height: 24),
        _buildPopularDishesSection(data),
      ],
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
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _buildDiscountVoucherCard(),
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
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildInfoCard('Total Revenue', '\$${data.totalIncome.toStringAsFixed(2)}', Icons.monetization_on, Colors.green),
            _buildInfoCard('Total Orders', data.totalOrders.toString(), Icons.receipt_long, Colors.blue),
            _buildInfoCard('Today\'s Revenue', '\$${data.dailyIncome.toStringAsFixed(2)}', Icons.today, Colors.purple),
            _buildInfoCard('Today\'s Orders', data.dailyOrders.toString(), Icons.event, Colors.teal),
            _buildInfoCard('Pending Orders', data.pendingOrders.toString(), Icons.hourglass_top, Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
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
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (data.orderRate.map((e) => e.orders).reduce((a, b) => a > b ? a : b) * 1.2).toDouble(), // Add 20% padding to max Y
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (double value, TitleMeta meta) {
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
      {'icon': Icons.fastfood_outlined, 'label': 'All'},
      {'icon': Icons.local_pizza_outlined, 'label': 'Pizza'},
      {'icon': Icons.cake_outlined, 'label': 'Dessert'},
      {'icon': Icons.local_drink_outlined, 'label': 'Drink'},
      {'icon': Icons.set_meal_outlined, 'label': 'Asian'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return _buildCategoryItem(categories[index]['icon'] as IconData, categories[index]['label'] as String);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 30, color: Colors.orangeAccent),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  Widget _buildPopularDishesSection(AnalyticsData data) {
    if (data.popularItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Popular Dishes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Responsive(
          mobile: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.popularItems.length,
            itemBuilder: (context, index) {
              final dish = data.popularItems[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildPopularDishItem(dish),
              );
            },
          ),
          desktop: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.8,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: data.popularItems.length,
            itemBuilder: (context, index) {
              final dish = data.popularItems[index];
              return _buildPopularDishItem(dish);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularDishItem(PopularItem dish) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: dish.image != null
                  ? Image.network(
                      dish.image!,
                      height: 60,
                      width: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.fastfood, color: Colors.orange, size: 50);
                      },
                    )
                  : const Icon(Icons.fastfood, color: Colors.orange, size: 50),
            ),
            const SizedBox(height: 8),
            Text(dish.name, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('${dish.count} orders', style: const TextStyle(color: Colors.grey)),
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
