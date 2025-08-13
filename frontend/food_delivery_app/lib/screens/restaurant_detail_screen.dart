import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/restaurant.dart';
import 'package:food_delivery_app/models/menu_item.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/screens/filter_dialog.dart';
import 'package:food_delivery_app/screens/cart_screen.dart';
import 'package:food_delivery_app/providers/cart_provider.dart';
import 'package:provider/provider.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<MenuItem>> _futureMenuItems;
  List<int> _selectedPreferenceIds = [];

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  void _loadMenuItems() {
    _futureMenuItems = _apiService.fetchMenuItems(widget.restaurant.id, dietaryPreferenceIds: _selectedPreferenceIds);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshData() async {
    // This triggers a re-fetch and updates the UI via setState in _loadMenuItems
    _loadMenuItems();
    // We await the future so the refresh indicator knows when to stop.
    await _futureMenuItems;
  }

  Future<void> _showFilterDialog() async {
    final List<int>? result = await showDialog<List<int>>(
      context: context,
      builder: (context) => FilterDialog(selectedIds: _selectedPreferenceIds),
    );

    if (result != null) {
      setState(() {
        _selectedPreferenceIds = result;
      });
      _loadMenuItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomCartBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(_selectedPreferenceIds.isEmpty ? Icons.filter_list : Icons.filter_list_alt),
                onPressed: _showFilterDialog,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: (widget.restaurant.imageUrl != null && widget.restaurant.imageUrl!.isNotEmpty)
                  ? Image.network(
                      widget.restaurant.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.restaurant, size: 60),
                      ),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.restaurant, size: 60),
                    ),
            ),
          ),
          
          // Restaurant info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.restaurant.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (widget.restaurant.averageRating > 0) ...[
                        Icon(
                          Icons.star,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.restaurant.averageRating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                      const SizedBox(width: 16),
                      Icon(
                        Icons.access_time,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.restaurant.deliveryTime} min',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.delivery_dining,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '\$${widget.restaurant.deliveryFee}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.restaurant.cuisineType,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Menu items
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: FutureBuilder<List<MenuItem>>(
              future: _futureMenuItems,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'Error loading menu: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('No menu items found.')),
                  );
                } else {
                  return SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = snapshot.data![index];
                        return MenuItemCard(item: item);
                      },
                      childCount: snapshot.data!.length,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      ), 
    );
  }
}

class MenuItemCard extends StatelessWidget {
  final MenuItem item;

  const MenuItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              AspectRatio(
                aspectRatio: 1.2,
                child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Icon(Icons.fastfood, size: 50, color: Colors.grey)),
                      )
                    : const Center(child: Icon(Icons.fastfood, size: 50, color: Colors.grey)),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.red),
                    onPressed: () { /* Handle favorite */ },
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$${item.price.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      InkWell(
                        onTap: () async {
                          final cartProvider = Provider.of<CartProvider>(context, listen: false);
                          final success = await cartProvider.addToCart(item.id);
                          if (!context.mounted) return;
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${item.name} added to cart'),
                                action: SnackBarAction(
                                  label: 'View Cart',
                                  onPressed: () {
                                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CartScreen()));
                                  },
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(cartProvider.error ?? 'Failed to add item.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BottomCartBar extends StatelessWidget {
  const BottomCartBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        if (cartProvider.cart == null || cartProvider.cart!.items.isEmpty) {
          return const SizedBox.shrink();
        }

        final itemCount = cartProvider.cart!.items.fold<int>(0, (sum, item) => sum + item.quantity);
        final total = cartProvider.cart!.items.fold<double>(0.0, (sum, item) => sum + ((item.menuItem?.price ?? 0.0) * item.quantity));

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CartScreen()));
          },
          child: Container(
            height: 60,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('View your cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(itemCount.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
        );
      },
    );
  }
}
