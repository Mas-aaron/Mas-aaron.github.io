import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/payment.dart';
import '../services/payment_service.dart';
import 'order_success_screen.dart';

class MobileMoneyPaymentScreen extends StatefulWidget {
  final PaymentMethod paymentMethod;
  final double amount;
  final String orderId;
  final VoidCallback onPaymentSuccess;

  const MobileMoneyPaymentScreen({
    Key? key,
    required this.paymentMethod,
    required this.amount,
    required this.orderId,
    required this.onPaymentSuccess,
  }) : super(key: key);

  @override
  State<MobileMoneyPaymentScreen> createState() => _MobileMoneyPaymentScreenState();
}

class _MobileMoneyPaymentScreenState extends State<MobileMoneyPaymentScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final PaymentService _paymentService = PaymentService();
  
  bool _isProcessing = false;
  String? _paymentId;
  Timer? _statusCheckTimer;
  int _statusCheckAttempts = 0;
  static const int _maxStatusCheckAttempts = 30; // 5 minutes max

  @override
  void dispose() {
    _phoneController.dispose();
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getPaymentMethodName()),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: _isProcessing ? _buildProcessingView() : _buildPaymentForm(),
    );
  }

  Widget _buildPaymentForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Method Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getPaymentMethodColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getPaymentMethodColor().withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.phone_android,
                    size: 48,
                    color: _getPaymentMethodColor(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getPaymentMethodName(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'UGX ${widget.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getPaymentMethodColor(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Phone Number Input
            const Text(
              'Phone Number',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                hintText: _getPhoneNumberHint(),
                prefixText: '+256 ',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _getPaymentMethodColor()),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (value.length != 9) {
                  return 'Please enter a valid phone number';
                }
                if (!_isValidPhoneNumber(value)) {
                  return 'Please enter a valid ${_getPaymentMethodName()} number';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Payment Instructions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getPaymentInstructions(),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPaymentMethodColor(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Pay Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _getPaymentMethodColor().withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phone_android,
                size: 60,
                color: _getPaymentMethodColor(),
              ),
            ),

            const SizedBox(height: 32),

            const CircularProgressIndicator(),

            const SizedBox(height: 24),

            Text(
              'Processing Payment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Please check your phone for a payment prompt from ${_getPaymentMethodName()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 32),

            OutlinedButton(
              onPressed: _cancelPayment,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel Payment'),
            ),
          ],
        ),
      ),
    );
  }

  String _getPaymentMethodName() {
    switch (widget.paymentMethod) {
      case PaymentMethod.mtnMobileMoney:
        return 'MTN Mobile Money';
      case PaymentMethod.airtelMoney:
        return 'Airtel Money';
      default:
        return 'Mobile Money';
    }
  }

  Color _getPaymentMethodColor() {
    switch (widget.paymentMethod) {
      case PaymentMethod.mtnMobileMoney:
        return Colors.yellow.shade700;
      case PaymentMethod.airtelMoney:
        return Colors.red.shade600;
      default:
        return Colors.orange;
    }
  }

  String _getPhoneNumberHint() {
    switch (widget.paymentMethod) {
      case PaymentMethod.mtnMobileMoney:
        return '77XXXXXXX or 78XXXXXXX';
      case PaymentMethod.airtelMoney:
        return '70XXXXXXX or 75XXXXXXX';
      default:
        return 'Enter phone number';
    }
  }

  String _getPaymentInstructions() {
    switch (widget.paymentMethod) {
      case PaymentMethod.mtnMobileMoney:
        return '1. You will receive a payment request on your phone\n'
               '2. Enter your Mobile Money PIN to authorize\n'
               '3. Wait for payment confirmation\n'
               '4. Your order will be confirmed automatically';
      case PaymentMethod.airtelMoney:
        return '1. You will receive a payment request on your phone\n'
               '2. Enter your Airtel Money PIN to authorize\n'
               '3. Wait for payment confirmation\n'
               '4. Your order will be confirmed automatically';
      default:
        return 'Follow the instructions on your phone to complete payment';
    }
  }

  bool _isValidPhoneNumber(String phone) {
    switch (widget.paymentMethod) {
      case PaymentMethod.mtnMobileMoney:
        return phone.startsWith('77') || phone.startsWith('78');
      case PaymentMethod.airtelMoney:
        return phone.startsWith('70') || phone.startsWith('75');
      default:
        return phone.length == 9;
    }
  }

  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    final fullPhoneNumber = '256${_phoneController.text}';

    final result = await _paymentService.initiatePayment(
      orderId: widget.orderId,
      paymentMethod: widget.paymentMethod,
      amount: widget.amount,
      phoneNumber: fullPhoneNumber,
    );

    if (result['success']) {
      // If backend already returns a status (sandbox often SUCCESSFUL), finish immediately
      final statusResponse = result['status_response'];
      final status = result['status'] ?? (statusResponse != null ? statusResponse['status'] : null);

      if (status != null && (status == 'SUCCESSFUL' || status == 'PENDING')) {
        _statusCheckTimer?.cancel();
        setState(() {
          _isProcessing = false;
        });
        
        // Extract transaction details
        final transactionId = statusResponse?['financialTransactionId']?.toString();
        
        // Navigate to success screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(
              orderId: int.tryParse(widget.orderId) ?? 0,
              totalAmount: widget.amount,
              transactionId: transactionId,
            ),
          ),
        );
        return;
      }

      // Otherwise, fall back to polling with payment_id
      _paymentId = result['payment_id'];
      _startStatusChecking();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Payment initiated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to initiate payment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startStatusChecking() {
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus() async {
    if (_paymentId == null) return;

    _statusCheckAttempts++;

    final result = await _paymentService.checkPaymentStatus(_paymentId!);

    if (result['success']) {
      final status = result['status'];
      
      if (status == 'completed') {
        _statusCheckTimer?.cancel();
        
        // Navigate to success screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(
              orderId: int.tryParse(widget.orderId) ?? 0,
              totalAmount: widget.amount,
            ),
          ),
        );
      } else if (status == 'failed' || status == 'cancelled') {
        _statusCheckTimer?.cancel();
        setState(() {
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment ${status}. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Stop checking after max attempts
    if (_statusCheckAttempts >= _maxStatusCheckAttempts) {
      _statusCheckTimer?.cancel();
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment timeout. Please check your transaction and try again.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _cancelPayment() async {
    if (_paymentId != null) {
      await _paymentService.cancelPayment(_paymentId!);
    }
    
    _statusCheckTimer?.cancel();
    Navigator.of(context).pop();
  }
}
