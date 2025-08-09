import 'package:flutter/material.dart';
import 'package:restaurant_dashboard_new/models/order.dart';
import 'package:restaurant_dashboard_new/services/order_service.dart';

class OrderPanel extends StatefulWidget {
  const OrderPanel({super.key});

  @override
  State<OrderPanel> createState() => _OrderPanelState();
}

class _OrderPanelState extends State<OrderPanel> {
  late Future<List<Order>> _ordersFuture;
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _ordersFuture = _orderService.getOrders();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final panelBackgroundColor = isDarkMode ? Colors.grey[850] : Colors.white;
    final cardBackgroundColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      width: 350,
      color: panelBackgroundColor,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Balance',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 16),
          _buildBalanceCard(),
          const SizedBox(height: 24),
          Text(
            'My Address',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 16),
          _buildAddressCard(cardBackgroundColor),
          const SizedBox(height: 24),
          _buildOrderMenuSection(textColor),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Balance', style: TextStyle(color: Colors.black54)),
              SizedBox(height: 4),
              Text('\$12.000', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
            ],
          ),
          Row(
            children: [
              _buildBalanceButton(Icons.arrow_upward, 'Top Up'),
              const SizedBox(width: 12),
              _buildBalanceButton(Icons.swap_horiz, 'Transfer'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBalanceButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.black, size: 20),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }

  Widget _buildOrderMenuSection(Color textColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Incoming Orders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              TextButton(
                onPressed: () {},
                child: const Text('View all >', style: TextStyle(color: Colors.orange)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Order>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No current orders.'));
                }

                final orders = snapshot.data!;
                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderItem(order, textColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Order order, Color textColor) {
    // Displaying the first item of the order for simplicity
    final firstItem = order.items.isNotEmpty ? order.items.first : null;

    if (firstItem == null) {
      return const SizedBox.shrink(); // Don't build a row for an order with no items
    }

    // Safely parse the total price
    final double totalPrice = order.totalPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // Using a placeholder icon since imageUrl is not available in the model
                child: const Icon(Icons.fastfood, size: 60, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(firstItem.menuItemName, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    Text('x${firstItem.quantity}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Text('\$${totalPrice.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            ],
          ),
          const SizedBox(height: 10),
          // Show buttons only for 'Pending' orders
          if (order.status == 'Pending')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _updateOrderStatus(order.id, 'Accepted'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Accept'),
                ),
                ElevatedButton(
                  onPressed: () => _updateOrderStatus(order.id, 'Rejected'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Reject'),
                ),
              ],
            )
          else
            Text('Status: ${order.status}', style: TextStyle(color: textColor.withOpacity(0.7))), // Show current status if not pending
        ],
      ),
    );
  }

  void _updateOrderStatus(int orderId, String status) async {
    try {
      await _orderService.updateOrderStatus(orderId, status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order has been $status')),
      );
      // Refresh the list of orders
      setState(() {
        _ordersFuture = _orderService.getOrders();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order: $e')),
      );
    }
  }

  Widget _buildAddressCard(Color cardBackgroundColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on_outlined, color: Colors.orangeAccent),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Home', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('2118 Thornridge Cir. Syracuse, Connecticut 35624', overflow: TextOverflow.ellipsis, maxLines: 2, style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('View', style: TextStyle(color: Colors.orange)),
          )
        ],
      ),
    );
  }
}
