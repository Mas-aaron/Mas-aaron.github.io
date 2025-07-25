import 'package:flutter/material.dart';
import 'package:rider_app/screens/available_orders_screen.dart';
import 'package:rider_app/screens/order_list_screen.dart';
import 'package:rider_app/services/api_service.dart';

class RiderHomeScreen extends StatefulWidget {
  final ApiService apiService;

  const RiderHomeScreen({super.key, required this.apiService});

  @override
  _RiderHomeScreenState createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rider Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.explore), text: 'Available Jobs'),
              Tab(icon: Icon(Icons.history), text: 'My Deliveries'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AvailableOrdersScreen(apiService: widget.apiService),
            OrderListScreen(apiService: widget.apiService),
          ],
        ),
      ),
    );
  }
}
