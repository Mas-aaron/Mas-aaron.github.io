import 'package:flutter/material.dart';
import '../models/payment.dart';
import 'pesapal_payment_screen.dart';
import 'mobile_money_payment_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final double amount;
  final String orderId;
  final VoidCallback onPaymentSuccess;

  const PaymentMethodScreen({
    Key? key,
    required this.amount,
    required this.orderId,
    required this.onPaymentSuccess,
  }) : super(key: key);

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  PaymentMethod? _selectedMethod;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Method'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // Amount Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.orange.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'UGX ${widget.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          // Payment Methods
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Choose Payment Method',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // MTN Mobile Money
                _buildPaymentMethodCard(
                  method: PaymentMethod.mtnMobileMoney,
                  title: 'MTN Mobile Money',
                  subtitle: 'Pay with MTN Mobile Money PIN',
                  icon: Icons.phone_android,
                  color: Colors.yellow.shade700,
                ),

                const SizedBox(height: 12),

                // Airtel Money
                _buildPaymentMethodCard(
                  method: PaymentMethod.airtelMoney,
                  title: 'Airtel Money',
                  subtitle: 'Pay with Airtel Money PIN',
                  icon: Icons.phone_android,
                  color: Colors.red.shade600,
                ),

                const SizedBox(height: 12),

                // Pesapal Payment (Mobile Money & Cards)
                _buildPaymentMethodCard(
                  method: PaymentMethod.pesapal,
                  title: 'Pesapal Payment',
                  subtitle: 'Pay with Mobile Money, Cards, or Bank Transfer',
                  icon: Icons.payment,
                  color: Colors.blue.shade600,
                ),

                const SizedBox(height: 12),

                // Cash on Delivery
                _buildPaymentMethodCard(
                  method: PaymentMethod.cashOnDelivery,
                  title: 'Cash on Delivery',
                  subtitle: 'Pay with cash when your order arrives',
                  icon: Icons.money,
                  color: Colors.green.shade600,
                ),
              ],
            ),
          ),

          // Continue Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedMethod != null ? _proceedWithPayment : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  _selectedMethod == PaymentMethod.cashOnDelivery
                      ? 'Confirm Order'
                      : 'Continue to Payment',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required PaymentMethod method,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? logo,
  }) {
    final isSelected = _selectedMethod == method;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.orange : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Logo or Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: logo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          logo,
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            icon,
                            color: color,
                            size: 24,
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        color: color,
                        size: 24,
                      ),
              ),

              const SizedBox(width: 16),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection Indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: isSelected ? Colors.orange : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _proceedWithPayment() {
    if (_selectedMethod == null) return;

    if (_selectedMethod == PaymentMethod.cashOnDelivery) {
      // For cash on delivery, just confirm the order
      widget.onPaymentSuccess();
      Navigator.of(context).pop();
    } else if (_selectedMethod == PaymentMethod.mtnMobileMoney || _selectedMethod == PaymentMethod.airtelMoney) {
      // For direct mobile money, navigate to mobile money payment screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MobileMoneyPaymentScreen(
            amount: widget.amount,
            orderId: widget.orderId,
            paymentMethod: _selectedMethod!,
            onPaymentSuccess: () {
              widget.onPaymentSuccess();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
      );
    } else {
      // For Pesapal payment, navigate to Pesapal payment screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PesapalPaymentScreen(
            amount: widget.amount,
            orderId: widget.orderId,
            onPaymentSuccess: () {
              widget.onPaymentSuccess();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
      );
    }
  }
}
