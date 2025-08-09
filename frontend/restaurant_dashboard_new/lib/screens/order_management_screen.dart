import 'package:flutter/material.dart';
import 'package:restaurant_dashboard_new/models/order.dart';
import 'package:restaurant_dashboard_new/services/order_service.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  List<Order>? _orders;
  bool _isLoading = true;
  String? _error;
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final orders = await _orderService.getOrders();
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(int orderId, String status) async {
    try {
      await _orderService.updateOrderStatus(orderId, status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #$orderId has been $status'), backgroundColor: Colors.green),
      );
      _fetchOrders(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Failed to load orders. Please check your connection and ensure the server is running.\n\nError: $_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_orders == null || _orders!.isEmpty) {
      return const Center(child: Text('No orders found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _orders!.length,
      itemBuilder: (context, index) {
        final order = _orders![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Chip(
                      label: Text(order.status),
                      backgroundColor: _getStatusColor(order.status),
                      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Text('Customer: ${order.customerName}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 4),
                Text('Total: \$${order.totalPrice}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Text('• ${item.quantity} x ${item.menuItemName} (\$${item.price} each)'),
                    )),
                const SizedBox(height: 16),
                _buildActionButtons(order),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(Order order) {
    switch (order.status) {
      case 'Pending':
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () => _updateOrderStatus(order.id, 'Rejected'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: const Text('Reject'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _updateOrderStatus(order.id, 'Accepted'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
              child: const Text('Accept'),
            ),
          ],
        );
      case 'Accepted':
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () => _updateOrderStatus(order.id, 'Preparing'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
              child: const Text('Start Preparing'),
            ),
          ],
        );
      case 'Preparing':
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () => _updateOrderStatus(order.id, 'Ready for Pickup'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade600),
              child: const Text('Mark as Ready'),
            ),
          ],
        );
      default:
        return const SizedBox.shrink(); // No actions for other statuses
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.shade700;
      case 'Preparing':
        return Colors.blue.shade700;
      case 'Ready for Pickup':
        return Colors.cyan.shade600;
      case 'Delivered':
        return Colors.green.shade700;
      case 'Cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade600;
    }
  }
}
