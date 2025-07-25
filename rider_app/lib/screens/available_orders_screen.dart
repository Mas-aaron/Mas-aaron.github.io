import 'package:flutter/material.dart';
import 'package:rider_app/models/order.dart';
import 'package:rider_app/services/api_service.dart';

class AvailableOrdersScreen extends StatefulWidget {
  final ApiService apiService;

  const AvailableOrdersScreen({super.key, required this.apiService});

  @override
  _AvailableOrdersScreenState createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  late Future<List<Order>> _availableOrdersFuture;

  @override
  void initState() {
    super.initState();
    _loadAvailableOrders();
  }

  void _loadAvailableOrders() {
    setState(() {
      _availableOrdersFuture = widget.apiService.getAvailableOrders();
    });
  }

  Future<void> _acceptOrder(int orderId) async {
    try {
      await widget.apiService.acceptOrder(orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order accepted! Check \'My Deliveries\'.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadAvailableOrders(); // Refresh the list to remove the accepted order
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept order: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Order>>(
      future: _availableOrdersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No available orders right now.'));
        } else {
          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text('Order #${order.id}'),
                  subtitle: Text('From: ${order.restaurantName}\nTo: ${order.deliveryAddress}'),
                  trailing: ElevatedButton(
                    onPressed: () => _acceptOrder(order.id),
                    child: const Text('Accept'),
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}
