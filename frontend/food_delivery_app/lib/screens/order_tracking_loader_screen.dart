import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/screens/order_tracking_screen.dart';

class OrderTrackingLoaderScreen extends StatefulWidget {
  final int orderId;

  const OrderTrackingLoaderScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  _OrderTrackingLoaderScreenState createState() => _OrderTrackingLoaderScreenState();
}

class _OrderTrackingLoaderScreenState extends State<OrderTrackingLoaderScreen> {
  @override
  void initState() {
    super.initState();
    _fetchOrderAndNavigate();
  }

  Future<void> _fetchOrderAndNavigate() async {
    try {
      final Order order = await ApiService().getOrderDetails(widget.orderId);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(order: order),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load order details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
