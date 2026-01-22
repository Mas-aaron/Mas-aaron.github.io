import 'package:flutter/material.dart';

class ErrorStateWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String title;

  const ErrorStateWidget({
    Key? key,
    this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.title = 'Oops! Something went wrong',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 64,
                      color: Colors.orange.shade600,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Message
            Text(
              _getUserFriendlyMessage(message),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Retry button
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getUserFriendlyMessage(String? technicalMessage) {
    if (technicalMessage == null) {
      return 'We encountered an issue. Please try again.';
    }

    final lowerMessage = technicalMessage.toLowerCase();

    // Network errors
    if (lowerMessage.contains('socket') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('network') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('closed before')) {
      return 'Unable to connect to the server.\nPlease check your internet connection and try again.';
    }

    // Server errors
    if (lowerMessage.contains('500') ||
        lowerMessage.contains('502') ||
        lowerMessage.contains('503') ||
        lowerMessage.contains('server error')) {
      return 'Our servers are having issues.\nPlease try again in a few moments.';
    }

    // Authentication errors
    if (lowerMessage.contains('401') ||
        lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('authentication')) {
      return 'Session expired.\nPlease log in again to continue.';
    }

    // Not found errors
    if (lowerMessage.contains('404') || lowerMessage.contains('not found')) {
      return 'The requested information could not be found.\nPlease try refreshing.';
    }

    // Timeout errors
    if (lowerMessage.contains('timeout')) {
      return 'Request timed out.\nThe server is taking too long to respond.';
    }

    // Generic fallback
    return 'Something went wrong.\nPlease try again or contact support if the issue persists.';
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    Key? key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Message
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Action button
            if (onAction != null && actionLabel != null)
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade600,
                  side: BorderSide(color: Colors.orange.shade600),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
