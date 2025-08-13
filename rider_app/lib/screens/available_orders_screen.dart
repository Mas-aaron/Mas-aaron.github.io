import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  bool _isLoading = false;

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
    setState(() {
      _isLoading = true;
    });
    try {
      await widget.apiService.acceptOrder(orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order accepted successfully!')),
      );
      _loadAvailableOrders(); // Refresh the list to remove the accepted order
    } on http.ClientException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order is no longer available.')),
      );
      _loadAvailableOrders(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                    onPressed: _isLoading ? null : () => _acceptOrder(order.id),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                          )
                        : const Text('Accept'),
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
