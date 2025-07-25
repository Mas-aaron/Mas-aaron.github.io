import 'package:flutter/material.dart';
import 'screens/dashboard_home_screen.dart';

void main() {
  runApp(const RestaurantDashboardApp());
}

class RestaurantDashboardApp extends StatelessWidget {
  const RestaurantDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFF9F6F2),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: const DashboardHomeScreen(),
    );
  }
}
