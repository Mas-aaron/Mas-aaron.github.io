import 'package:flutter/material.dart';

class AppSidebar extends StatefulWidget {
  final Function(int) onItemSelected;

  const AppSidebar({super.key, required this.onItemSelected});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 48, // Account for vertical padding
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16.0, bottom: 32.0),
                  child: Text(
                    'FortExpress.',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                Column(
                  children: [
                    _buildNavItem(Icons.dashboard_outlined, 'Dashboard', 0),
                    _buildNavItem(Icons.receipt_long_rounded, 'Food Order', 1),
                    _buildNavItem(Icons.star_border_rounded, 'Reviews', 2),
                    _buildNavItem(Icons.restaurant_menu_outlined, 'Menu', 3),
                    _buildNavItem(Icons.history_rounded, 'Order History', 4),
                    _buildNavItem(Icons.wallet_rounded, 'Bills', 5),
                    _buildNavItem(Icons.payment_outlined, 'Payments', 6),
                    _buildNavItem(Icons.notifications_outlined, 'Notification', 7),
                    _buildNavItem(Icons.settings_outlined, 'Settings', 8),
                  ],
                ),
                const Spacer(),
                _buildUpgradeCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        widget.onItemSelected(index);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFC107) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.grey[600]),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Upgrade your Account to Get Free Voucher',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}
