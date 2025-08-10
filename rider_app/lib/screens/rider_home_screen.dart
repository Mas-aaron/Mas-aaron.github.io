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
    print("[RiderHomeScreen] initState CALLED");
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService(
      onMessageReceived: (data) {
        if (data['type'] == 'new.order') {
          _showNewOrderNotification(data['order']);
        }
      },
    );
    _connectWebSocket();
  }

  void _connectWebSocket() async {
    try {
      print('[WebSocket] Attempting to connect...');
      final token = await ApiService.getToken();
      if (token != null) {
        _webSocketService.connect(token);
      } else {
        print('[WebSocket] Auth Token is null. Cannot connect.');
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
          onAccept: () async {
            try {
              await _apiService.acceptOrder(order['id']);
              OverlaySupportEntry.of(context)!.dismiss();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order accepted!'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              print('Failed to accept order: $e');
              OverlaySupportEntry.of(context)!.dismiss();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to accept order: $e')),
              );
            }
          },
          onDecline: () {
            OverlaySupportEntry.of(context)!.dismiss();
          },
        );
      },
      duration: const Duration(seconds: 15),
      position: NotificationPosition.top,
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    print("[RiderHomeScreen] dispose CALLED");
    _webSocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider App'),
        centerTitle: true,
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Available Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'My Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'My Reviews',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}