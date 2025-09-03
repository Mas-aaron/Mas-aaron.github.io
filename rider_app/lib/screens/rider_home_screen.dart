import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:rider_app/services/api_service.dart';
import 'package:rider_app/services/websocket_service.dart';
import 'package:rider_app/screens/available_orders_screen.dart';
import 'package:rider_app/screens/order_list_screen.dart';
import 'package:rider_app/screens/my_reviews_screen.dart';
import 'package:rider_app/widgets/new_order_notification.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  _RiderHomeScreenState createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  late WebSocketService _webSocketService;
  final ApiService _apiService = ApiService();
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      AvailableOrdersScreen(apiService: _apiService),
      OrderListScreen(apiService: _apiService),
      const MyReviewsScreen(),
    ];
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService(
      onMessageReceived: (data) {
        if (data['type'] == 'new_order') {
          _showNewOrderNotification(data['order']);
        }
      },
    );
    _connectWebSocket();
  }

  void _connectWebSocket() async {
    try {
      final token = await ApiService.getToken();
      if (token != null) {
        _webSocketService.connect(token);
      }
    } catch (e) {
      print('[WebSocket] Error connecting: $e');
    }
  }

  void _showNewOrderNotification(Map<String, dynamic> order) {
    showOverlayNotification(
      (context) {
        return NewOrderNotificationCard(
          order: order,
          onAccept: () => _acceptOrderAndNavigate(context, order['id'] as int),
          onDecline: () {
            OverlaySupportEntry.of(context)!.dismiss();
          },
        );
      },
      duration: const Duration(hours: 1),
      position: NotificationPosition.top,
    );
  }

  void _acceptOrderAndNavigate(BuildContext overlayContext, int orderId) async {
    OverlaySupportEntry.of(overlayContext)!.dismiss();

    try {
      await _apiService.acceptOrder(orderId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Order accepted successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      _onItemTapped(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C851).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delivery_dining, color: Color(0xFF00C851), size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FortExpress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Rider',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, size: 24),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF00C851).withOpacity(0.1),
              child: const Icon(Icons.person, color: Color(0xFF00C851), size: 20),
            ),
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.motorcycle, 'Available', 0),
                _buildNavItem(Icons.assignment, 'Active', 1),
                _buildNavItem(Icons.star_rounded, 'Reviews', 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C851).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00C851) : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00C851) : Colors.grey[600],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}