import 'package:flutter/material.dart';
import 'package:rider_app/models/order.dart';
import 'package:rider_app/screens/order_tracking_screen.dart';
import 'package:rider_app/services/api_service.dart';

class OrderListScreen extends StatefulWidget {
  final ApiService apiService;

  const OrderListScreen({super.key, required this.apiService});

  @override
  _OrderListScreenState createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  late Future<List<Order>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = widget.apiService.getAssignedOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assigned Orders'),
      ),
      body: FutureBuilder<List<Order>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No assigned orders found.'));
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
                    subtitle: Text('Status: ${order.status}'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => OrderTrackingScreen(order: order, apiService: widget.apiService),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
