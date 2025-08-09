import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:restaurant_dashboard_new/utils/responsive.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Responsive(
          mobile: _buildMobileLayout(),
          desktop: _buildDesktopLayout(),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPositiveReviewCard(),
        const SizedBox(height: 24),
        _buildDiscountVoucherCard(),
        const SizedBox(height: 24),
        _buildCategorySection(),
        const SizedBox(height: 24),
        _buildPopularDishesSection(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildPositiveReviewCard(),
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
        _buildPopularDishesSection(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'What do you want to eat today?',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.shopping_bag_outlined), onPressed: () {}),
            IconButton(icon: const Icon(Icons.notifications_none_outlined), onPressed: () {}),
            const SizedBox(width: 8),
            CircleAvatar(
              child: ClipOval(
                child: Image.network(
                  'https://i.pravatar.cc/150?img=3',
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.person, color: Colors.grey);
                  },
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildPositiveReviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Positive Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text('20, 08:22 AM', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('3.678', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Text('Reviews', style: TextStyle(color: Colors.grey, height: 2.5)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_upward, color: Colors.green, size: 16),
                    Text('+15%', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: _reviewChartBottomTitleWidgets,
                      reservedSize: 30,
                    ),
                  ),
                ),
                barGroups: _getBarGroups(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _getBarGroups() {
    final barRods = [
      _makeBarRodData(toY: 15, color: Colors.redAccent),
      _makeBarRodData(toY: 10, color: Colors.orangeAccent),
      _makeBarRodData(toY: 8, color: Colors.redAccent),
      _makeBarRodData(toY: 12, color: Colors.orangeAccent, isTouched: true),
      _makeBarRodData(toY: 6, color: Colors.redAccent),
      _makeBarRodData(toY: 13, color: Colors.orangeAccent),
      _makeBarRodData(toY: 16, color: Colors.redAccent),
    ];
    return List.generate(barRods.length, (index) {
      return BarChartGroupData(x: index, barRods: [barRods[index]]);
    });
  }

  BarChartRodData _makeBarRodData({required double toY, required Color color, bool isTouched = false}) {
    return BarChartRodData(
      toY: toY,
      color: isTouched ? Colors.amber : color,
      width: 20,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(6),
      ),
    );
  }

  static SideTitleWidget _reviewChartBottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(color: Colors.grey, fontSize: 12);
    Widget text;
    switch (value.toInt()) {
      case 0: text = const Text('Mon', style: style); break;
      case 1: text = const Text('Tue', style: style); break;
      case 2: text = const Text('Wed', style: style); break;
      case 3: text = const Text('Thu', style: style); break;
      case 4: text = const Text('Fri', style: style); break;
      case 5: text = const Text('Sat', style: style); break;
      case 6: text = const Text('Sun', style: style); break;
      default: text = const Text('', style: style); break;
    }
    return SideTitleWidget(
      space: 8.0,
      meta: meta, //margin of titles
      child: text,
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () {},
              child: const Text('View all >', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildCategoryItem(Icons.bakery_dining, 'Bakery'),
              _buildCategoryItem(Icons.fastfood, 'Burger'),
              _buildCategoryItem(Icons.local_cafe, 'Beverage'),
              _buildCategoryItem(Icons.set_meal, 'Chicken'),
              _buildCategoryItem(Icons.local_pizza, 'Pizza'),
              _buildCategoryItem(Icons.ramen_dining, 'Seafood'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(IconData icon, String label) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: Colors.orangeAccent),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPopularDishesSection() {
    final List<Map<String, String>> popularDishesData = [
      {'name': 'Fish Burger', 'price': '5.59', 'imageUrl': 'https://i.pravatar.cc/150?img=5', 'rating': '4.9'},
      {'name': 'Beef Burger', 'price': '6.29', 'imageUrl': 'https://i.pravatar.cc/150?img=6', 'rating': '4.8'},
      {'name': 'Cheese Burger', 'price': '4.99', 'imageUrl': 'https://i.pravatar.cc/150?img=7', 'rating': '4.9'},
      {'name': 'Chicken Pizza', 'price': '8.99', 'imageUrl': 'https://i.pravatar.cc/150?img=8', 'rating': '4.7'},
      {'name': 'Veggie Delight', 'price': '5.29', 'imageUrl': 'https://i.pravatar.cc/150?img=9', 'rating': '4.6'},
      {'name': 'Spicy Wings', 'price': '7.49', 'imageUrl': 'https://i.pravatar.cc/150?img=10', 'rating': '4.8'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Popular Dishes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () {},
              child: const Text('View all >', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Responsive(
          mobile: SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: popularDishesData.length,
              itemBuilder: (context, index) {
                final dish = popularDishesData[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 16),
                  child: _buildPopularDishItem(dish['name']!, dish['price']!, dish['imageUrl']!, dish['rating']!),
                );
              },
            ),
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
            itemCount: popularDishesData.length,
            itemBuilder: (context, index) {
              final dish = popularDishesData[index];
              return _buildPopularDishItem(dish['name']!, dish['price']!, dish['imageUrl']!, dish['rating']!);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularDishItem(String name, String price, String imageUrl, String rating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl, 
                height: 120, 
                width: double.infinity, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.fastfood, color: Colors.grey, size: 50);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: const Text('15% Off', style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('\$$price', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                Text(rating, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ],
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
