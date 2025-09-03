import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/order.dart';
import 'package:food_delivery_app/utils/currency_formatter.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/services/websocket_service.dart';
import 'package:food_delivery_app/screens/order_tracking_screen.dart';
import 'package:food_delivery_app/widgets/error_display.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ApiService _apiService = ApiService();
  WebSocketService? _webSocketService;

  @override
  void initState() {
    super.initState();
    _loadOrdersAndInitWebSocket();
  }

  Future<void> _loadOrdersAndInitWebSocket() async {
    await _loadOrders();
    if (_errorMessage == null) {
      _initWebSocket();
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _apiService.fetchOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading orders: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load orders: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _initWebSocket() {
    _webSocketService = WebSocketService(
      onMessageReceived: (data) {
        if (data['type'] == 'order_status_update') {
          final orderId = data['order_id'];
          final newStatus = data['status'];
          if (mounted) {
            setState(() {
              final index = _orders.indexWhere((o) => o.id == orderId);
              if (index != -1) {
                _orders[index] = _orders[index].copyWith(status: newStatus);
              }
            });
          }
        }
      },
    );
    _webSocketService!.connect();
  }

  void _navigateToTrackingScreen(Order order) {
    const trackableStatuses = {
      'accepted',
      'preparing',
      'ready for pickup',
      'assigned',
      'out for delivery'
    };

    if (trackableStatuses.contains(order.status.toLowerCase())) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OrderTrackingScreen(order: order),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This order is not available for live tracking (Status: ${order.status}).'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _getStatusChip(String status) {
    Color chipColor;
    IconData chipIcon;

    switch (status.toLowerCase()) {
      case 'pending':
        chipColor = Colors.grey;
        chipIcon = Icons.hourglass_empty;
        break;
      case 'accepted':
        chipColor = Colors.blue;
        chipIcon = Icons.check_circle_outline;
        break;
      case 'preparing':
        chipColor = Colors.orange;
        chipIcon = Icons.restaurant;
        break;
      case 'ready for pickup':
      case 'assigned':
        chipColor = Colors.purple;
        chipIcon = Icons.local_shipping_outlined;
        break;
      case 'out for delivery':
        chipColor = Colors.cyan;
        chipIcon = Icons.delivery_dining;
        break;
      case 'delivered':
        chipColor = Colors.green;
        chipIcon = Icons.check_circle;
        break;
      case 'cancelled':
        chipColor = Colors.red;
        chipIcon = Icons.cancel;
        break;
      default:
        chipColor = Colors.black;
        chipIcon = Icons.help_outline;
    }

    return Chip(
      avatar: Icon(chipIcon, color: Colors.white, size: 18),
      label: Text(status, style: const TextStyle(color: Colors.white)),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
    );
  }

  @override
  void dispose() {
    _webSocketService?.disconnect();
    super.dispose();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorDisplayWidget(
        errorMessage: _errorMessage!,
        onRetry: _loadOrdersAndInitWebSocket,
      );
    }

    if (_orders.isEmpty) {
      return const Center(child: Text('You have no active orders.'));
    }

    return ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final createdAtDate = DateTime.parse(order.createdAt);
        final double totalPrice = double.tryParse(order.totalPrice) ?? 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _navigateToTrackingScreen(order),
            borderRadius: BorderRadius.circular(12),
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
                      Text(
                        CurrencyFormatter.formatUGX(totalPrice),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Placed on: ${DateFormat.yMMMd().format(createdAtDate)}'),
                      _getStatusChip(order.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Active Orders'),
        backgroundColor: Colors.orange,
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _buildBody(),
      ),
    );
  }
}
