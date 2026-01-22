import 'package:flutter/material.dart';
import 'package:food_delivery_app/utils/currency_formatter.dart';
import 'package:food_delivery_app/screens/set_location_screen.dart';
import 'package:food_delivery_app/widgets/error_display.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/location_provider.dart';
import '../models/cart.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch cart data when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCart();
    });
  }

  Future<void> _refreshCart() async {
    await Provider.of<CartProvider>(context, listen: false).fetchCart();
  }

  void _placeOrder(Cart cart) {
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(cart: cart),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        elevation: 0,
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          return RefreshIndicator(
            onRefresh: _refreshCart,
            color: Colors.orange,
            backgroundColor: Colors.white,
            child: Column(
              children: [
                if (cartProvider.isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (cartProvider.error != null)
                  Expanded(
                    child: Center(
                      child: ErrorDisplayWidget(
                        errorMessage: cartProvider.error!,
                        onRetry: _refreshCart,
                      ),
                    ),
                  )
                else if (cartProvider.cart == null || cartProvider.cart!.items.isEmpty)
                  const Expanded(
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 300,
                        child: Center(
                          child: Text(
                            'Your cart is empty.',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(), // Ensure the list is always scrollable
                      padding: const EdgeInsets.all(16.0),
                      itemCount: cartProvider.cart!.items.length,
                      itemBuilder: (context, index) {
                        final item = cartProvider.cart!.items[index];
                        return _CartItemCard(item: item);
                      },
                    ),
                  ),
                if (!cartProvider.isLoading &&
                    cartProvider.error == null &&
                    cartProvider.cart != null &&
                    cartProvider.cart!.items.isNotEmpty)
                  _OrderSummaryCard(
                    cart: cartProvider.cart!,
                    onPlaceOrder: () => _placeOrder(cartProvider.cart!),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final dynamic item; // Using dynamic to access properties easily

  const _CartItemCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                item.menuItem?.imageUrl ?? 'https://via.placeholder.com/150',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => 
                  const Icon(Icons.image_not_supported, size: 60),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.menuItem?.name ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.formatUGX(item.menuItem?.price ?? 0.0)
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _buildQuantityButton(context, Icons.remove, () {
                  if (item.quantity > 1) {
                    cartProvider.updateItemQuantity(item.id, item.quantity - 1);
                  } else {
                    cartProvider.removeItem(item.id);
                  }
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _buildQuantityButton(context, Icons.add, () {
                  cartProvider.updateItemQuantity(item.id, item.quantity + 1);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton(BuildContext context, IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 18, color: Theme.of(context).primaryColor),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final Cart cart;
  final VoidCallback onPlaceOrder;

  const _OrderSummaryCard({
    Key? key,
    required this.cart,
    required this.onPlaceOrder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const deliveryFee = 5.00;
    final total = cart.totalPrice + deliveryFee;

    return Card(
      margin: const EdgeInsets.all(0),
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAddressSection(context),
            const SizedBox(height: 16),
            _buildPriceRow('Subtotal', cart.totalPrice),
            const SizedBox(height: 8),
            _buildPriceRow('Delivery Fee', deliveryFee),
            const Divider(height: 24, thickness: 1),
            _buildTotalRow('Total', total),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPlaceOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('Place Order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final address = locationProvider.currentAddress ?? 'No address set. Tap to select.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Delivery Address',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SetLocationScreen()),
                );
              },
              child: const Text('Change'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            address,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
        Text(CurrencyFormatter.formatUGX(amount), style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildTotalRow(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(
          CurrencyFormatter.formatUGX(amount),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}