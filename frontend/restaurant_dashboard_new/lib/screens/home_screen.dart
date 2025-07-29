import 'package:flutter/material.dart';
import 'analytics_screen.dart'; // We will create this next

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // We will add other screens here later
  static final List<Widget> _widgetOptions = <Widget>[
    const AnalyticsScreen(),
    const Text('Menu Management - Coming Soon'), // Placeholder for Menu screen
    const Text('Order Management - Coming Soon'), // Placeholder for Orders screen
    const Text('Reviews - Coming Soon'), // Placeholder for Reviews screen
    const Text('Settings - Coming Soon'), // Placeholder for Settings screen
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.selected,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                'GoMeal',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.restaurant_menu_outlined),
                selectedIcon: Icon(Icons.restaurant_menu),
                label: Text('Menu'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Food Order'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.reviews_outlined),
                selectedIcon: Icon(Icons.reviews),
                label: Text('Reviews'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // This is the main content.
          Expanded(
            child: _widgetOptions.elementAt(_selectedIndex),
          )
        ],
      ),
    );
  }
}
