import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/menu_item.dart';
import 'package:food_delivery_app/utils/currency_formatter.dart';
import 'package:food_delivery_app/models/restaurant.dart';
import 'package:food_delivery_app/screens/cart_screen.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/models/menu_category.dart';
import 'package:food_delivery_app/widgets/error_display.dart';
import 'package:food_delivery_app/providers/cart_provider.dart';
import 'package:food_delivery_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';

class MenuScreen extends StatefulWidget {
  final Restaurant restaurant;

  const MenuScreen({super.key, required this.restaurant});

  @override
  _MenuScreenState createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<MenuCategory> _menu = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final menu = await apiService.fetchMenu(widget.restaurant.id);
      if (mounted) {
        setState(() {
          _menu = menu;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load menu. Please check your connection and try again.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: ErrorDisplayWidget(
          errorMessage: _errorMessage!,
          onRetry: _loadMenu,
        ),
      );
    }

    if (_menu.isEmpty) {
      return const Center(child: Text('This restaurant has no menu available.'));
    }

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final category = _menu[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                    child: Text(
                      category.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...category.items.map((item) => _MenuItemCard(item: item, apiService: apiService)),
                ],
              );
            },
            childCount: _menu.length,
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.shopping_cart),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(widget.restaurant.name, style: const TextStyle(fontSize: 16.0)),
        background: Stack(
          fit: StackFit.expand,
          children: [
            OptimizedImage(
              imageUrl: widget.restaurant.imageUrl,
              fit: BoxFit.cover,
            ),
            Container(color: Colors.black.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final ApiService apiService;

  const _MenuItemCard({required this.item, required this.apiService});

  void _addToCart(BuildContext context) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    cartProvider.addMenuItemToCartOptimistic(item);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to cart'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Ensures the InkWell ripple is contained
      child: InkWell(
        onTap: () => _addToCart(context),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      CurrencyFormatter.formatUGX(item.price),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.add_circle,
                color: theme.colorScheme.primary,
                size: 36,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
