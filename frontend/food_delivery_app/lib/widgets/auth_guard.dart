import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';

/// A widget that protects routes by checking authentication status
/// Shows login screen with descriptive message if user is not authenticated
class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? redirectMessage;

  const AuthGuard({
    Key? key,
    required this.child,
    this.redirectMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading spinner while checking authentication
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Checking your login status...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        // If authenticated, show the protected content
        if (authProvider.isAuthenticated) {
          return child;
        }

        // If not authenticated, show login screen with descriptive message
        return Scaffold(
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.orange.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Login Required',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              redirectMessage ?? 
                              'Please log in to access this feature and start ordering delicious food from your favorite restaurants.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Expanded(child: LoginScreen()),
            ],
          ),
        );
      },
    );
  }
}

/// Extension to easily wrap routes with authentication
extension AuthGuardExtension on Widget {
  Widget requireAuth({String? message}) {
    return AuthGuard(
      redirectMessage: message,
      child: this,
    );
  }
}
