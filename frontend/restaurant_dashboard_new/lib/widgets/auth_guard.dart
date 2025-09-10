import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';

/// A widget that protects routes by checking authentication status
/// Shows login screen if user is not authenticated
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
                    'Checking authentication...',
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

        // If not authenticated, show login screen with message
        return Scaffold(
          body: Column(
            children: [
              if (redirectMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.orange.shade100,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          redirectMessage!,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
