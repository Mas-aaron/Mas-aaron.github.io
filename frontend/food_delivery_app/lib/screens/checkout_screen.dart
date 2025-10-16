import 'package:flutter/material.dart';
import 'package:food_delivery_app/utils/currency_formatter.dart';
import 'package:food_delivery_app/screens/set_location_screen.dart';
import 'package:food_delivery_app/screens/payment_method_screen.dart';
import 'package:food_delivery_app/widgets/order_type_selector.dart';
import 'package:food_delivery_app/widgets/tip_selector.dart';
import 'package:provider/provider.dart';
import '../models/cart.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';

class CheckoutScreen extends StatefulWidget {
  final Cart cart;

  const CheckoutScreen({Key? key, required this.cart}) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;

  Future<void> _proceedToPayment() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final position = locationProvider.currentPosition;
    final address = locationProvider.currentAddress;

    // Only require location for delivery orders
    if (cartProvider.orderType == OrderType.delivery && (position == null || address == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a delivery address first.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Calculate total amount
    const deliveryFee = 5.00;
    final subtotal = widget.cart.totalPrice;
    final tip = cartProvider.tipAmount;
    final hasDeliveryFee = cartProvider.orderType == OrderType.delivery;
    final total = subtotal + (hasDeliveryFee ? deliveryFee : 0) + tip;

    // First create the order
    setState(() {
      _isLoading = true;
    });

    final result = await cartProvider.placeOrder(
      cartProvider.orderType == OrderType.delivery ? address : null,
      position?.latitude,
      position?.longitude,
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      final orderId = result['order_id']?.toString() ?? '';
      
      // Navigate to payment method selection
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaymentMethodScreen(
            amount: total,
            orderId: orderId,
            onPaymentSuccess: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order placed successfully!'), backgroundColor: Colors.green),
              );
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
      );
    } else {
      final errorMessage = result['error'] ?? 'Failed to place order. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        elevation: 0,
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
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
              _buildPaymentCard(),
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  child: const Icon(Icons.delivery_dining, color: Colors.white, size: 24),
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
                color: isSelected ? Colors.white.withOpacity(0.9) : Colors.orange.shade600,
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Consumer<LocationProvider>(
        builder: (context, locationProvider, child) {
          final address = locationProvider.currentAddress ?? 'No address selected';
          return ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(address),
            trailing: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SetLocationScreen()),
                );
              },
              child: const Text('Change'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.payment_outlined, color: Colors.orange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Payment will be selected on next step',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPaymentOption(Icons.phone_android, 'MTN Money', Colors.yellow.shade700),
                const SizedBox(width: 8),
                _buildPaymentOption(Icons.phone_android, 'Airtel Money', Colors.red.shade600),
                const SizedBox(width: 8),
                _buildPaymentOption(Icons.money, 'Cash', Colors.green.shade600),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
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

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPriceRow('Subtotal', subtotal),
            const SizedBox(height: 8),
            if (hasDeliveryFee) ...[
              _buildPriceRow('Delivery Fee', deliveryFee),
              const SizedBox(height: 8),
            ],
            if (tip > 0) ...[
              _buildPriceRow('Tip', tip),
              const SizedBox(height: 8),
            ],
            const Divider(height: 24),
            _buildTotalRow('Total', total),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade700)),
        Text(CurrencyFormatter.formatUGX(amount)),
      ],
    );
  }

  Widget _buildTotalRow(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(CurrencyFormatter.formatUGX(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  Widget _buildConfirmOrderButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _proceedToPayment,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : const Text('Confirm Order'),
        ),
      ),
    );
  }
}
