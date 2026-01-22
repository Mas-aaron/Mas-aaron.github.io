import 'package:flutter/material.dart';
import 'package:food_delivery_app/utils/currency_formatter.dart';
import 'package:food_delivery_app/screens/order_tracking_loader_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final int orderId;
  final double totalAmount;
  final String estimatedTime;
  final String? transactionId;

  const OrderSuccessScreen({
    Key? key,
    required this.orderId,
    required this.totalAmount,
    this.estimatedTime = '30-40 minutes',
    this.transactionId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navigate to home instead of going back
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Animation
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 120,
                    color: Colors.green.shade600,
                  ),
                ),

                const SizedBox(height: 32),

                // Success Message
                Text(
                  'Order Confirmed!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  'Your payment was successful',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Order Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Order ID', '#${orderId.toString()}', Icons.receipt_long),
                      const Divider(height: 24),
                      _buildDetailRow('Total Paid', CurrencyFormatter.formatUGX(totalAmount), Icons.payments),
                      if (transactionId != null) ...[
                        const Divider(height: 24),
                        _buildDetailRow('Transaction ID', transactionId!, Icons.confirmation_number),
                      ],
                      const Divider(height: 24),
                      _buildDetailRow('Estimated Time', estimatedTime, Icons.schedule),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Info Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'The restaurant is now preparing your order. You can track the progress below.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Track Order Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => OrderTrackingLoaderScreen(orderId: orderId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_searching),
                    label: const Text('Track Your Order'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Return to Home Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Return to Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
