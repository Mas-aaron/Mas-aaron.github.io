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
        return OverlaySupport.global(
          child: MaterialApp(
          title: 'Restaurant Dashboard',
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
              ? HomeScreen()
              : const LoginScreen(),
          routes: {
            LoginScreen.routeName: (context) => const LoginScreen(),
            SignUpScreen.routeName: (context) => SignUpScreen(),
            SettingsScreen.routeName: (ctx) => SettingsScreen(),
            ManageCategoriesScreen.routeName: (ctx) => ManageCategoriesScreen(),
            MenuManagementScreen.routeName: (context) => const MenuManagementScreen(),
            HomeScreen.routeName: (context) => HomeScreen(),
            OrderProtocolScreen.routeName: (context) => OrderProtocolScreen(),
          },
        ),
        );
      },
    );
  }
}
