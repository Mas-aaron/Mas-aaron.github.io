import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

import '../widgets/order_notification.dart';
import 'package:restaurant_dashboard_new/services/websocket_service.dart';
import 'package:restaurant_dashboard_new/widgets/app_sidebar.dart';
import 'package:restaurant_dashboard_new/widgets/order_panel.dart';
import 'package:restaurant_dashboard_new/screens/menu_management_screen.dart';
import 'package:restaurant_dashboard_new/screens/notification_screen.dart';
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

  final List<Widget> _screens = [
    const AnalyticsScreen(),
    const OrderManagementScreen(),
    const Center(child: Text('Favorite Screen')),
    const MenuManagementScreen(),
    const Center(child: Text('Order History Screen')),
    const Center(child: Text('Bills Screen')),
    const NotificationScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService(
      onInitialOrders: (orders) {},
      onNewOrder: (order) {
        if (!mounted) return;
        showOverlayNotification(
          (context) {
            return OrderNotification(order: order);
          },
          duration: const Duration(seconds: 8),
        );
      },
      onOrderUpdate: (order) {},
    );
    _webSocketService.connect();
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
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
              const Expanded(
                flex: 2,
                child: OrderPanel(),
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
          const Text('Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          const CircleAvatar(
            backgroundImage: NetworkImage('https://via.placeholder.com/150'),
          ),
        ],
      ),
    );
  }
}
