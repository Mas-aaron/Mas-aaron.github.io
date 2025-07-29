import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AuthProvider(),
      child: MaterialApp(
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
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Using a simple check on the token, which is loaded asynchronously.
    // A Consumer or a FutureBuilder could provide a loading screen.
    return authProvider.isAuthenticated ? const DashboardScreen() : const LoginScreen();
  }
}
