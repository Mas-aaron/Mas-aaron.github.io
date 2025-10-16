import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import 'package:restaurant_dashboard_new/widgets/app_sidebar.dart';
import 'package:restaurant_dashboard_new/widgets/order_panel.dart';
import 'package:restaurant_dashboard_new/screens/menu_management_screen.dart';
import 'package:restaurant_dashboard_new/screens/notification_screen.dart';
import 'package:restaurant_dashboard_new/screens/reviews_screen.dart';
import 'package:restaurant_dashboard_new/screens/order_history_screen.dart';
import 'package:restaurant_dashboard_new/screens/bills_screen.dart';
import 'package:restaurant_dashboard_new/screens/payments_screen.dart';
import 'package:restaurant_dashboard_new/screens/settings_screen.dart';
import 'package:restaurant_dashboard_new/screens/order_management_screen.dart';
import 'analytics_screen.dart';
import 'package:restaurant_dashboard_new/utils/responsive.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  late WebSocketService _webSocketService;
  ScaffoldMessengerState? _scaffoldMessengerState;

  final List<Widget> _screens = [
    const AnalyticsScreen(),
    const OrderManagementScreen(),
    ReviewsScreen(),
    const MenuManagementScreen(),
    OrderHistoryScreen(),
    BillsScreen(),
    const PaymentsScreen(),
    const NotificationScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the ScaffoldMessengerState
    _scaffoldMessengerState = ScaffoldMessenger.of(context);
  }

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService(
      onMessageReceived: (data) {
        if (data['type'] == 'new_orders' && data['orders'] is List && (data['orders'] as List).isNotEmpty) {
          // The backend sends a list, so we take the first order.
          final order = (data['orders'] as List).first;
          _showNewOrderNotification(order);
        }
      },
    );
    _connectWebSocket();
  }

  void _connectWebSocket() async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token != null) {
        _webSocketService.connect(token);
      }
    } catch (e) {
      print('[WebSocket] Error connecting: $e');
    }
  }

  void _showNewOrderNotification(Map<String, dynamic> order) {
    if (!mounted) return;
    // Use the cached ScaffoldMessengerState
    _scaffoldMessengerState?.showSnackBar(
      SnackBar(
        content: Text('New order received! ID: ${order['id']}'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 5),
      ),
    );
    // You might want to refresh the order list here
    // For example, by calling a method on your OrderPanel/OrderList widget
  }

  @override
  void dispose() {
    _webSocketService.disconnect(); // Disconnect first to prevent errors
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppSidebar(
        onItemSelected: (index) {
          _onItemTapped(index);
          Navigator.of(context).pop();
        },
      ),
      body: SafeArea(
        child: Responsive(
          desktop: Row(
            children: [
              AppSidebar(onItemSelected: _onItemTapped),
              Expanded(
                flex: 5,
                child: _screens[_selectedIndex],
              ),
              Expanded(
                flex: 2,
                child: OrderPanel(onViewMorePressed: () => _onItemTapped(1)),
              ),
            ],
          ),
          mobile: Column(
            children: [
              _buildMobileHeader(),
              Expanded(
                child: _screens[_selectedIndex],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            child: CircleAvatar(
              backgroundColor: Colors.orange[100],
              child: Icon(Icons.person, color: Colors.orange[600]),
            ),
          ),
        ],
      ),
    );
  }
}
