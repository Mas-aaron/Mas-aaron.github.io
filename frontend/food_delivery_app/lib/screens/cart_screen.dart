import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/cart.dart';
import 'package:food_delivery_app/models/cart_item.dart';
import 'package:food_delivery_app/services/api_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<CartItem>> futureCartItems;
  final ApiService apiService = ApiService();
  final _addressController = TextEditingController();


  @override
  void initState() {
    super.initState();
    futureCartItems = apiService.getCartItems();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _loadCart() {
    setState(() {
      futureCartItems = apiService.getCartItems();
    });
  }

  void _updateQuantity(int cartItemId, int newQuantity) async {
    try {
      if (newQuantity > 0) {
        await apiService.updateCartItem(cartItemId, newQuantity);
      } else {
        await apiService.deleteCartItem(cartItemId);
      }
      _loadCart();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update cart: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    }
  }

  void _placeOrder(String address) async {
    try {
      final order = await apiService.placeOrder(address);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order placed successfully! Order ID: ${order.id}')),
      );
      _loadCart();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place order: ${e.toString().replaceAll("Exception: ", "")}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Cart'),
        elevation: 0,
      ),
      body: FutureBuilder<List<CartItem>>(
        future: futureCartItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading cart. Please try again.'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            );
          } else {
            // Create a Cart object on the fly from the list of items
            final cart = Cart(id: 0, items: snapshot.data!, createdAt: DateTime.now().toIso8601String());
            return SingleChildScrollView(
              child: Column(
                children: [
                  ListView.builder(
                    // Important: shrinkWrap and physics are needed for a ListView inside a SingleChildScrollView
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _CartItemCard(
                        item: item,
                        onUpdateQuantity: _updateQuantity,
                      );
                    },
                  ),
                  _OrderSummaryCard(cart: cart, addressController: _addressController, onPlaceOrder: _placeOrder),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final Function(int, int) onUpdateQuantity;

  const _CartItemCard({required this.item, required this.onUpdateQuantity});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // IMAGE (safe)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (item.menuItem.imageUrl != null && item.menuItem.imageUrl!.isNotEmpty)
                  ? Image.network(
                      item.menuItem.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey[200],
                        child: Icon(Icons.fastfood, size: 32, color: Colors.orange),
                      ),
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey[200],
                      child: Icon(Icons.fastfood, size: 32, color: Colors.orange),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.menuItem.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('\$${item.menuItem.price}', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            Row(
              children: [
                _buildQuantityButton(Icons.remove, () => onUpdateQuantity(item.id, item.quantity - 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('${item.quantity}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                _buildQuantityButton(Icons.add, () => onUpdateQuantity(item.id, item.quantity + 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final Cart cart;
  final TextEditingController addressController;
  final Function(String) onPlaceOrder;

  const _OrderSummaryCard({
    required this.cart,
    required this.addressController,
    required this.onPlaceOrder,
  });

  double _calculateSubtotal(Cart cart) {
    return cart.items.fold(0, (total, item) => total + (item.menuItem.price * item.quantity));
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _calculateSubtotal(cart);
    final deliveryFee = 5.00; // Example fee
    final total = subtotal + deliveryFee;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: addressController,
              decoration: InputDecoration(
                labelText: 'Delivery Address',
                hintText: 'Enter your full address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(height: 16),
            _buildPriceRow('Subtotal', subtotal),
            SizedBox(height: 8),
            _buildPriceRow('Delivery Fee', deliveryFee),
            Divider(height: 24),
            _buildPriceRow('Total', total, isTotal: true),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Place Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (addressController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a delivery address.')),
                    );
                    return;
                  }
                  onPlaceOrder(addressController.text);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String title, double value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.black : Colors.grey[600],
          ),
        ),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
