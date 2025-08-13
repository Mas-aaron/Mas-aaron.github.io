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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Rider Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(12),
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
          child: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.local_shipping_outlined),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfe5722).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping),
                ),
                label: 'Available',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.history_outlined),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfe5722).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history),
                ),
                label: 'My Orders',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.star_outline),
                ),
                activeIcon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfe5722).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.star),
                ),
                label: 'Reviews',
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: const Color(0xFFfe5722),
            unselectedItemColor: Colors.grey[600],
            showSelectedLabels: true,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            onTap: _onItemTapped,
            selectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}