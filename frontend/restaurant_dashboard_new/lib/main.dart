import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/manage_categories_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/order_protocol_screen.dart';
import 'screens/menu_management_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, authProvider, child) {
        // Show loading screen while initializing
        if (authProvider.isLoading) {
          return MaterialApp(
            title: 'FortExpress Restaurant',
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.orange,
              scaffoldBackgroundColor: const Color(0xFFF7F7F7),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            home: const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading FortExpress Restaurant...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return OverlaySupport.global(
          child: MaterialApp(
            title: 'FortExpress Restaurant',
            theme: ThemeData(
              brightness: Brightness.light,
              primarySwatch: Colors.orange,
              scaffoldBackgroundColor: const Color(0xFFF7F7F7),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primarySwatch: Colors.orange,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            themeMode: themeProvider.themeMode,
            home: authProvider.isAuthenticated
                ? const HomeScreen()
                : const LoginScreen(),
            routes: {
              LoginScreen.routeName: (context) => const LoginScreen(),
              SignUpScreen.routeName: (context) => SignUpScreen(),
              SettingsScreen.routeName: (ctx) => SettingsScreen(),
              ManageCategoriesScreen.routeName: (ctx) => ManageCategoriesScreen(),
              MenuManagementScreen.routeName: (context) => const MenuManagementScreen(),
              HomeScreen.routeName: (context) => const HomeScreen(),
              OrderProtocolScreen.routeName: (context) => OrderProtocolScreen(),
            },
          ),
        );
      },
    );
  }
}
