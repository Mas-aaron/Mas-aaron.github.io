import 'package:flutter/material.dart';
import 'package:food_delivery_app/utils/currency_formatter.dart';
import 'package:food_delivery_app/screens/set_location_screen.dart';
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

  Future<void> _placeOrder() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
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
              // Order Type Info
              _buildOrderTypeInfo(cartProvider),
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

  Widget _buildOrderTypeInfo(CartProvider cartProvider) {
    String orderTypeText = '';
    IconData orderTypeIcon = Icons.delivery_dining;
    
    switch (cartProvider.orderType) {
      case OrderType.delivery:
        orderTypeText = 'Delivery Order';
        orderTypeIcon = Icons.delivery_dining;
        break;
      case OrderType.pickup:
        orderTypeText = 'Pickup Order';
        orderTypeIcon = Icons.store;
        break;
      case OrderType.dineIn:
        orderTypeText = 'Dine-in Order';
        orderTypeIcon = Icons.restaurant;
        break;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(orderTypeIcon, color: Theme.of(context).primaryColor),
        title: Text(orderTypeText, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: cartProvider.orderType == OrderType.dineIn && cartProvider.scheduledTime != null
            ? Text('Scheduled for ${_formatDateTime(cartProvider.scheduledTime!)}')
            : null,
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
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Table will be assigned upon arrival',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
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
      child: ListTile(
        leading: const Icon(Icons.payment_outlined),
        title: const Text('Cash on Delivery'),
        trailing: TextButton(onPressed: () {}, child: const Text('Change')),
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
          onPressed: _isLoading ? null : _placeOrder,
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
