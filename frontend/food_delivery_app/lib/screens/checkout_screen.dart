import 'package:flutter/material.dart';
import 'package:food_delivery_app/utils/currency_formatter.dart';
import 'package:food_delivery_app/screens/set_location_screen.dart';
import 'package:food_delivery_app/screens/order_success_screen.dart';
import 'package:food_delivery_app/widgets/order_type_selector.dart';
import 'package:food_delivery_app/widgets/tip_selector.dart';
import 'package:provider/provider.dart';
import '../models/cart.dart';
import '../models/payment.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../services/payment_service.dart';

class CheckoutScreen extends StatefulWidget {
  final Cart cart;

  const CheckoutScreen({Key? key, required this.cart}) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;
  PaymentMethod? _selectedPaymentMethod;
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final PaymentService _paymentService = PaymentService();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _proceedToPayment() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final position = locationProvider.currentPosition;
    final address = locationProvider.currentAddress;

    // Only require location for delivery orders
    if (cartProvider.orderType == OrderType.delivery &&
        (position == null || address == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please set a delivery address first.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Validate payment method selection
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a payment method.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Validate phone number for mobile money payments
    if ((_selectedPaymentMethod == PaymentMethod.mtnMobileMoney ||
            _selectedPaymentMethod == PaymentMethod.airtelMoney) &&
        !_formKey.currentState!.validate()) {
      return;
    }

    // Calculate total amount
    const deliveryFee = 5.00;
    final subtotal = widget.cart.totalPrice;
    final tip = cartProvider.tipAmount;
    final hasDeliveryFee = cartProvider.orderType == OrderType.delivery;
    final total = subtotal + (hasDeliveryFee ? deliveryFee : 0) + tip;

    setState(() {
      _isLoading = true;
    });

    // Step 1: Create the order
    final orderResult = await cartProvider.placeOrder(
      cartProvider.orderType == OrderType.delivery ? address : null,
      position?.latitude,
      position?.longitude,
    );

    if (!orderResult['success']) {
      setState(() {
        _isLoading = false;
      });
      final errorMessage =
          orderResult['error'] ?? 'Failed to place order. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      return;
    }

    final orderId = orderResult['order_id']?.toString() ?? '';

    // Step 2: Process payment based on selected method
    if (_selectedPaymentMethod == PaymentMethod.cashOnDelivery) {
      // Cash on delivery - order is created, no payment processing needed
      setState(() {
        _isLoading = false;
      });
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            orderId: int.tryParse(orderId) ?? 0,
            totalAmount: total,
          ),
        ),
      );
      return;
    }

    // Step 3: Process mobile money payment
    if (_selectedPaymentMethod == PaymentMethod.mtnMobileMoney ||
        _selectedPaymentMethod == PaymentMethod.airtelMoney) {
      try {
        final paymentResult = await _paymentService.initiatePayment(
          orderId: orderId,
          paymentMethod: _selectedPaymentMethod!,
          amount: total,
          phoneNumber: _phoneController.text.trim(),
        );

        setState(() {
          _isLoading = false;
        });

        if (paymentResult['success']) {
          // Check if payment completed immediately (sandbox)
          final statusResponse = paymentResult['status_response'];
          final status = paymentResult['status'] ??
              (statusResponse != null ? statusResponse['status'] : null);

          if (status != null &&
              (status == 'SUCCESSFUL' || status == 'PENDING')) {
            // Payment successful, navigate to success screen
            final transactionId =
                statusResponse?['financialTransactionId']?.toString();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => OrderSuccessScreen(
                  orderId: int.tryParse(orderId) ?? 0,
                  totalAmount: total,
                  transactionId: transactionId,
                ),
              ),
            );
          } else {
            // Payment initiated, show message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(paymentResult['message'] ??
                    'Payment initiated. Please check your phone.'),
                backgroundColor: Colors.orange,
              ),
            );
            // Still navigate to success screen as order is created
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => OrderSuccessScreen(
                  orderId: int.tryParse(orderId) ?? 0,
                  totalAmount: total,
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(paymentResult['error'] ??
                  'Payment failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    // For other payment methods (PesaPal, etc.)
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Payment method not yet implemented'),
          backgroundColor: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Checkout',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          return ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            children: [
              // Order Type Selection
              _buildOrderTypeSelector(cartProvider),
              const SizedBox(height: 24),

              // Address section (only for delivery)
              if (cartProvider.orderType == OrderType.delivery) ...[
                _buildSectionTitle('Delivery Address'),
                _buildAddressCard(),
                const SizedBox(height: 24),
              ],

              // Dine-in info (only for dine-in)
              if (cartProvider.orderType == OrderType.dineIn) ...[
                _buildSectionTitle('Dine-in Details'),
                _buildDineInCard(cartProvider),
                const SizedBox(height: 24),
              ],

              // Tip section (for dine-in orders)
              if (cartProvider.orderType == OrderType.dineIn) ...[
                _buildSectionTitle('Add Tip (Optional)'),
                TipSelector(
                  subtotal: widget.cart.totalPrice,
                  selectedTip: cartProvider.tipAmount,
                  onTipChanged: (double tip) {
                    cartProvider.setTipAmount(tip);
                  },
                ),
                const SizedBox(height: 24),
              ],

              _buildSectionTitle('Payment Method'),
              _buildPaymentSelection(),
              const SizedBox(height: 24),
              if (_selectedPaymentMethod == PaymentMethod.mtnMobileMoney ||
                  _selectedPaymentMethod == PaymentMethod.airtelMoney)
                _buildPhoneNumberInput(),
              if (_selectedPaymentMethod == PaymentMethod.mtnMobileMoney ||
                  _selectedPaymentMethod == PaymentMethod.airtelMoney)
                const SizedBox(height: 24),
              _buildSectionTitle('Order Summary'),
              _buildOrderSummaryCard(cartProvider),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildConfirmOrderButton(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildOrderTypeSelector(CartProvider cartProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delivery_dining,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Order Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select how you\'d like to receive your order',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildOrderTypeOption(
                    OrderType.delivery,
                    'Delivery',
                    Icons.delivery_dining,
                    'Delivered to your door',
                    cartProvider.orderType == OrderType.delivery,
                    () => cartProvider.setOrderType(OrderType.delivery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOrderTypeOption(
                    OrderType.pickup,
                    'Pickup',
                    Icons.store,
                    'Collect from restaurant',
                    cartProvider.orderType == OrderType.pickup,
                    () => cartProvider.setOrderType(OrderType.pickup),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOrderTypeOption(
                    OrderType.dineIn,
                    'Dine-in',
                    Icons.restaurant,
                    'Eat at restaurant',
                    cartProvider.orderType == OrderType.dineIn,
                    () => cartProvider.setOrderType(OrderType.dineIn),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeOption(
    OrderType type,
    String title,
    IconData icon,
    String description,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.orange.shade600 : Colors.orange.shade200,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.orange.shade300.withOpacity(0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.white : Colors.orange.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? Colors.white.withOpacity(0.9)
                    : Colors.orange.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDineInCard(CartProvider cartProvider) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  cartProvider.scheduledTime != null
                      ? 'Scheduled for ${_formatDateTime(cartProvider.scheduledTime!)}'
                      : 'ASAP',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.table_restaurant, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Table number (optional)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      cartProvider.setTableNumber(value.isEmpty ? null : value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours';
    } else {
      return '${dateTime.day}/${dateTime.month} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildAddressCard() {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        final address =
            locationProvider.currentAddress ?? 'No address selected';
        final hasAddress = locationProvider.currentAddress != null;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasAddress ? Colors.green.shade200 : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      hasAddress ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on,
                  color:
                      hasAddress ? Colors.green.shade600 : Colors.grey.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery To',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SetLocationScreen()),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentSelection() {
    return Column(
      children: [
        _buildPaymentMethodCard(
          PaymentMethod.mtnMobileMoney,
          'MTN Mobile Money',
          'Pay with MTN MoMo',
          Icons.phone_android,
          Colors.yellow.shade700,
          Colors.yellow.shade50,
        ),
        const SizedBox(height: 12),
        _buildPaymentMethodCard(
          PaymentMethod.airtelMoney,
          'Airtel Money',
          'Pay with Airtel Money',
          Icons.phone_android,
          Colors.red.shade600,
          Colors.red.shade50,
        ),
        const SizedBox(height: 12),
        _buildPaymentMethodCard(
          PaymentMethod.cashOnDelivery,
          'Cash on Delivery',
          'Pay when you receive',
          Icons.payments_outlined,
          Colors.green.shade600,
          Colors.green.shade50,
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(
    PaymentMethod method,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Color lightColor,
  ) {
    final isSelected = _selectedPaymentMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = method;
          if (method == PaymentMethod.cashOnDelivery) {
            _phoneController.clear();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Icon Container
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : lightColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Radio Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneNumberInput() {
    final color = _selectedPaymentMethod == PaymentMethod.mtnMobileMoney
        ? Colors.yellow.shade700
        : Colors.red.shade600;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.phone_android,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone Number',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      Text(
                        'Enter your mobile money number',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Phone Input
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                hintText: '256 783 876 390',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.normal,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: color, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }

                // Remove any spaces or special characters
                final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');

                // Check for Uganda format (256XXXXXXXXX)
                if (!cleaned.startsWith('256')) {
                  return 'Phone must start with 256 (Uganda)';
                }

                if (cleaned.length != 12) {
                  return 'Phone must be 12 digits (256XXXXXXXXX)';
                }

                // Validate MTN prefixes (77, 78)
                if (_selectedPaymentMethod == PaymentMethod.mtnMobileMoney) {
                  final prefix = cleaned.substring(3, 5);
                  if (prefix != '77' && prefix != '78') {
                    return 'MTN numbers must start with 77 or 78';
                  }
                }

                // Validate Airtel prefixes (70, 75)
                if (_selectedPaymentMethod == PaymentMethod.airtelMoney) {
                  final prefix = cleaned.substring(3, 5);
                  if (prefix != '70' && prefix != '75') {
                    return 'Airtel numbers must start with 70 or 75';
                  }
                }

                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              _selectedPaymentMethod == PaymentMethod.mtnMobileMoney
                  ? 'Enter your MTN Mobile Money number (77X or 78X)'
                  : 'Enter your Airtel Money number (70X or 75X)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(CartProvider cartProvider) {
    const deliveryFee = 5.00;
    final subtotal = widget.cart.totalPrice;
    final tip = cartProvider.tipAmount;
    final hasDeliveryFee = cartProvider.orderType == OrderType.delivery;
    final total = subtotal + (hasDeliveryFee ? deliveryFee : 0) + tip;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPriceRow('Subtotal', subtotal),
          const SizedBox(height: 12),
          if (hasDeliveryFee) ...[
            _buildPriceRow('Delivery Fee', deliveryFee),
            const SizedBox(height: 12),
          ],
          if (tip > 0) ...[
            _buildPriceRow('Tip', tip),
            const SizedBox(height: 12),
          ],
          Divider(height: 24, color: Colors.orange.shade300, thickness: 1),
          _buildTotalRow('Total', total),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          CurrencyFormatter.formatUGX(amount),
          style: TextStyle(
            color: Colors.grey.shade900,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.orange.shade900,
          ),
        ),
        Text(
          CurrencyFormatter.formatUGX(amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.orange.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmOrderButton() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _proceedToPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.zero,
            ),
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Processing...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Confirm Order',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
