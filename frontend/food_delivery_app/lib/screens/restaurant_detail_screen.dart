import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/restaurant.dart';
import 'package:food_delivery_app/utils/currency_formatter.dart';
import 'package:food_delivery_app/models/menu_item.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/screens/filter_dialog.dart';
import 'package:food_delivery_app/screens/cart_screen.dart';
import 'package:food_delivery_app/providers/cart_provider.dart';
import 'package:food_delivery_app/services/distance_service.dart';
import 'package:food_delivery_app/widgets/error_state_widget.dart';
import 'package:food_delivery_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';

class RestaurantDetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late Future<List<MenuItem>> _futureMenuItems;
  List<int> _selectedPreferenceIds = [];
  String _distance = 'Calculating...';
  int _selectedTabIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<String> _tabs = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadMenuItems();
    _calculateDistance();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateDistance() async {
    final distance = await DistanceService.getFormattedDistanceFromCurrentLocation(
      widget.restaurant.lat,
      widget.restaurant.lng,
    );
    if (mounted) {
      setState(() {
        _distance = distance;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _apiService.fetchRestaurantCategories(widget.restaurant.id);
      if (mounted) {
        setState(() {
          _tabs = ['All', ...categories]; // Add 'All' as first option
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _tabs = ['All']; // Fallback to just 'All'
        });
      }
    }
  }

  void _loadMenuItems() {
    // Get the selected category (null for 'All')
    String? category = _selectedTabIndex > 0 ? _tabs[_selectedTabIndex] : null;
    
    _futureMenuItems = _apiService.fetchMenuItems(
      widget.restaurant.id, 
      dietaryPreferenceIds: _selectedPreferenceIds,
      category: category,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshData() async {
    _loadMenuItems();
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
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshData,
            child: CustomScrollView(
              slivers: [
                // Hero Image Header
                SliverToBoxAdapter(
                  child: _buildHeroHeader(),
                ),
                
                // Tabs
                SliverToBoxAdapter(
                  child: _buildTabs(),
                ),
                
                // Menu Items
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: _buildMenuGrid(),
                ),
              ],
            ),
          ),
          
          // Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
                color: Colors.black87,
              ),
            ),
          ),
          
          // Floating Favorite Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.favorite_border, size: 20),
                onPressed: () {},
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomCartBar(),
    );
  }

  Widget _buildHeroHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Hero Image
          Container(
            height: 280,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  widget.restaurant.imageUrl ?? 'https://via.placeholder.com/400x280',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Gradient Overlay
          Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
          
          // Restaurant Info Card
          Positioned(
            left: 16,
            right: 16,
            bottom: -30,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Name & Logo
                  Row(
                    children: [
                      // Restaurant Logo
                      RestaurantLogoImage(
                        imageUrl: widget.restaurant.imageUrl,
                        size: 60,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.restaurant.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.restaurant.address,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Info Badges Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoBadge(
                        icon: Icons.star,
                        text: widget.restaurant.averageRating.toStringAsFixed(1),
                        color: Colors.yellow.shade700,
                      ),
                      _buildInfoBadge(
                        icon: Icons.access_time,
                        text: '${widget.restaurant.deliveryTime} Min',
                        color: Colors.orange.shade600,
                      ),
                      _buildInfoBadge(
                        icon: Icons.delivery_dining,
                        text: 'Free Delivery',
                        color: Colors.green.shade600,
                      ),
                    ],
                  ),
                  
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge({required IconData icon, required String text, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.only(top: 50, left: 16, right: 16, bottom: 16),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
                _loadMenuItems(); // Reload menu items when tab changes
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(right: index < _tabs.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.shade600 : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Text(
                  _tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMenuGrid() {
    return FutureBuilder<List<MenuItem>>(
      future: _futureMenuItems,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return SliverFillRemaining(
            child: ErrorStateWidget(
              message: snapshot.error.toString(),
              onRetry: _loadMenuItems,
              icon: Icons.restaurant_menu_outlined,
              title: 'Menu Unavailable',
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(
            child: EmptyStateWidget(
              message: _selectedTabIndex > 0 
                  ? 'No items in this category.\nTry selecting a different category.'
                  : 'No menu items available yet.\nCheck back soon!',
              icon: Icons.restaurant_outlined,
            ),
          );
        } else {
          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = snapshot.data![index];
                return _buildMenuItem(item);
              },
              childCount: snapshot.data!.length,
            ),
          );
        }
      },
    );
  }

  Widget _buildMenuItem(MenuItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Stack(
            children: [
              OptimizedImage(
                imageUrl: item.imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                errorWidget: Container(
                  height: 120,
                  color: Colors.grey[300],
                  child: const Icon(Icons.fastfood, size: 40),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite_border, size: 16),
                ),
              ),
            ],
          ),
          
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  
                  // Price & Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          CurrencyFormatter.formatUGX(item.price),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _addToCart(item.id),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade600,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(int menuItemId) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final success = await cartProvider.addToCart(menuItemId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to cart!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }
  }
}

class BottomCartBar extends StatelessWidget {
  const BottomCartBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final cart = cartProvider.cart;
        final itemCount = cart?.items.length ?? 0;

        if (itemCount == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade600, Colors.orange.shade700],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$itemCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'View Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.formatUGX(cart?.totalPrice ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
