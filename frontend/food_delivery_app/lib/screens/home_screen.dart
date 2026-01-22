import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/restaurant.dart';
import 'package:food_delivery_app/providers/location_provider.dart';
import 'package:food_delivery_app/screens/set_location_screen.dart';
import 'package:food_delivery_app/services/api_service.dart';
import 'package:food_delivery_app/services/distance_service.dart';
import 'package:food_delivery_app/widgets/error_state_widget.dart';
import 'package:food_delivery_app/widgets/optimized_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'restaurant_detail_screen.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Restaurant> _restaurants = [];
  List<Restaurant> _searchResults = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSearching = false;
  final ApiService _apiService = ApiService();
  Set<int> _favoriteRestaurantIds = {};
  Map<int, String> _restaurantDistances = {};
  Position? _currentPosition;
  
  // Enhanced animations
  late AnimationController _headerAnimationController;
  late AnimationController _contentAnimationController;
  late AnimationController _staggerAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<double> _scaleAnimation;
  
  int _selectedCategoryIndex = -1;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _getCurrentLocation();
    
    // Initialize enhanced animations
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _staggerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _headerFadeAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    );
    
    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _contentFadeAnimation = CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeInOutCubic,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOutBack,
    ));

    _scrollController.addListener(_onScroll);
    
    _loadData();
    
    // Enhanced animation sequence
    Future.delayed(const Duration(milliseconds: 100), () {
      _headerAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _contentAnimationController.forward();
        _staggerAnimationController.forward();
      });
    });
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _headerAnimationController.dispose();
    _contentAnimationController.dispose();
    _staggerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final restaurants = await _apiService.fetchRestaurants();
      
      if (mounted) {
        setState(() {
          _restaurants = restaurants;
          _isLoading = false;
        });
        _calculateDistances();
      }
      
      try {
        await context.read<LocationProvider>().determineInitialLocation();
      } catch (locationError) {
        print('Location service failed: $locationError');
      }
      
    } catch (e) {
      print('Restaurant fetch failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await DistanceService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
        _calculateDistances();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _calculateDistances() {
    if (_currentPosition == null || _restaurants.isEmpty) return;
    
    for (var restaurant in _restaurants) {
      if (restaurant.lat != 0.0 && restaurant.lng != 0.0) {
        try {
          final distance = DistanceService.calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            restaurant.lat,
            restaurant.lng,
          );
          setState(() {
            _restaurantDistances[restaurant.id] = DistanceService.formatDistance(distance);
          });
        } catch (e) {
          print('Error calculating distance for ${restaurant.name}: $e');
        }
      }
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('favorite_restaurants') ?? [];
      setState(() {
        _favoriteRestaurantIds = favorites.map((id) => int.parse(id)).toSet();
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(int restaurantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        if (_favoriteRestaurantIds.contains(restaurantId)) {
          _favoriteRestaurantIds.remove(restaurantId);
        } else {
          _favoriteRestaurantIds.add(restaurantId);
        }
      });
      await prefs.setStringList(
        'favorite_restaurants',
        _favoriteRestaurantIds.map((id) => id.toString()).toList(),
      );
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  Future<void> _refreshData() async {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _selectedCategoryIndex = -1;
    });
    await _loadData();
  }

  Future<void> _searchRestaurants(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = _restaurants
          .where((restaurant) =>
              restaurant.name.toLowerCase().contains(query.toLowerCase()) ||
              restaurant.cuisineType.toLowerCase().contains(query.toLowerCase()))
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToSetLocationScreen(LocationProvider locationProvider) {
    final currentPosition = locationProvider.currentPosition;
    LatLng? initialLatLng;
    if (currentPosition != null) {
      initialLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SetLocationScreen(initialPosition: initialLatLng),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header with Location
            _buildModernHeader(context),
            // Search Bar
            _buildSearchBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: Colors.orange.shade600,
                backgroundColor: Colors.white,
                displacement: 40,
                edgeOffset: 20,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        final displayAddress = locationProvider.currentAddress ?? 'Set Your Location';
        final isFetchingLocation = locationProvider.currentAddress == null;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Location Section - Highly Visible
              Expanded(
                child: GestureDetector(
                  onTap: () => _navigateToSetLocationScreen(locationProvider),
                  child: Row(
                    children: [
                      // Orange Location Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Location Text
                      Expanded(
                        child: isFetchingLocation
                            ? _buildLocationShimmer()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Deliver to',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: Colors.orange.shade600,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    displayAddress,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade900,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Notification Bell
              GestureDetector(
                onTap: () {
                  // Handle notification tap
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.notifications,
                          color: Colors.orange.shade600,
                          size: 24,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.orange.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 120,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return FadeTransition(
      opacity: _headerFadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _headerAnimationController,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
        )),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.shade200.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -5,
                ),
              ],
              border: Border.all(
                color: Colors.orange.shade100,
                width: 2,
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search restaurants, cuisine, or dishes...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.shade400.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.search_rounded, color: Colors.white, size: 20),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? ScaleTransition(
                        scale: _headerFadeAnimation,
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, color: Colors.grey.shade700, size: 16),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchRestaurants('');
                          },
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.tune_rounded, color: Colors.grey.shade500, size: 22),
                        onPressed: () {},
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: false,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onChanged: _searchRestaurants,
              style: TextStyle(color: Colors.grey.shade900, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && !_isSearching) {
      return _buildLoadingShimmer();
    }

    if (_errorMessage != null) {
      return ErrorStateWidget(
        message: _errorMessage,
        onRetry: _loadData,
        icon: Icons.cloud_off_outlined,
        title: 'Connection Issue',
      );
    }

    if (_isSearching) {
      return _buildSearchResults();
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _contentFadeAnimation,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildCategories(),
            _buildPromoBanner(),
            _buildTopPicks(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ShimmerLoader(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _buildCategories() {
    final categories = [
      {'icon': Icons.local_pizza, 'label': 'Pizza', 'color': Colors.orange, 'emoji': '🍕'},
      {'icon': Icons.lunch_dining, 'label': 'Burger', 'color': Colors.red, 'emoji': '🍔'},
      {'icon': Icons.restaurant, 'label': 'Asian', 'color': Colors.amber, 'emoji': '🍜'},
      {'icon': Icons.fastfood, 'label': 'Fast Food', 'color': Colors.deepOrange, 'emoji': '🍟'},
      {'icon': Icons.cake, 'label': 'Desserts', 'color': Colors.pink, 'emoji': '🍰'},
      {'icon': Icons.coffee, 'label': 'Cafe', 'color': Colors.brown, 'emoji': '☕'},
      {'icon': Icons.local_bar, 'label': 'Drinks', 'color': Colors.blue, 'emoji': '🥤'},
      {'icon': Icons.emoji_food_beverage, 'label': 'Healthy', 'color': Colors.green, 'emoji': '🥗'},
    ];

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                if (_selectedCategoryIndex != -1)
                  ScaleTransition(
                    scale: _contentFadeAnimation,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategoryIndex = -1;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategoryIndex == index;
                
                return CategoryItem(
                  category: category,
                  index: index,
                  isSelected: isSelected,
                  animationController: _staggerAnimationController,
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = isSelected ? -1 : index;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildPromoBanner() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1200),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.85 + (value * 0.15),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: () {
              // Handle promo banner tap
            },
            child: Stack(
            children: [
              // Main banner with enhanced gradient
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepOrange.shade400,
                      Colors.orange.shade600,
                      Colors.amber.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Animated floating elements
                    Positioned(
                      right: -30,
                      top: -30,
                      child: ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _staggerAnimationController,
                          curve: Curves.elasticOut,
                        ),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 40,
                      bottom: -20,
                      child: ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _staggerAnimationController,
                          curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
                        ),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'SPECIAL OFFER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange.shade700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '25% OFF\nYour First Order',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Use code: WELCOME25',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  SliverList _buildTopPicks() {
    final displayRestaurants = _restaurants.take(10).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final restaurant = displayRestaurants[index];
          return Padding(
            padding: EdgeInsets.fromLTRB(20, index == 0 ? 8 : 0, 20, 16),
            child: _AnimatedRestaurantCard(
              restaurant: restaurant,
              index: index,
              distance: _restaurantDistances[restaurant.id],
              isFavorite: _favoriteRestaurantIds.contains(restaurant.id),
              onFavoriteToggle: () => _toggleFavorite(restaurant.id),
            ),
          );
        },
        childCount: displayRestaurants.length,
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(
                parent: _staggerAnimationController,
                curve: Curves.elasticOut,
              ),
              child: Icon(Icons.search_off, size: 100, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 20),
            Text(
              'No restaurants found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _AnimatedRestaurantCard(
          restaurant: _searchResults[index],
          index: index,
          distance: _restaurantDistances[_searchResults[index].id],
          isFavorite: _favoriteRestaurantIds.contains(_searchResults[index].id),
          onFavoriteToggle: () => _toggleFavorite(_searchResults[index].id),
        );
      },
    );
  }
}

// Enhanced Category Item with better animations
class CategoryItem extends StatelessWidget {
  final Map<String, dynamic> category;
  final int index;
  final bool isSelected;
  final AnimationController animationController;
  final VoidCallback onTap;

  const CategoryItem({
    super.key,
    required this.category,
    required this.index,
    required this.isSelected,
    required this.animationController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: animationController,
      curve: Interval(
        0.1 + (index * 0.1),
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.5, end: 1.0).animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(right: 12),
            width: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [
                        category['color'].shade600,
                        category['color'].shade400,
                      ]
                    : [
                        Colors.white,
                        Colors.grey.shade50,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: category['color'].shade400.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
              border: Border.all(
                color: isSelected
                    ? category['color'].shade400
                    : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  category['emoji'] as String,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  category['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Enhanced Restaurant Card with parallax and advanced animations
class _AnimatedRestaurantCard extends StatefulWidget {
  final Restaurant restaurant;
  final int index;
  final String? distance;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _AnimatedRestaurantCard({
    required this.restaurant,
    required this.index,
    this.distance,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  State<_AnimatedRestaurantCard> createState() => _AnimatedRestaurantCardState();
}

class _AnimatedRestaurantCardState extends State<_AnimatedRestaurantCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 800 + (widget.index * 200)),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
    ));

    _rotateAnimation = Tween<double>(
      begin: 2.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    Future.delayed(Duration(milliseconds: widget.index * 150), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Transform(
            transform: Matrix4.rotationZ(_rotateAnimation.value * 0.01),
            alignment: Alignment.center,
            child: _buildCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  RestaurantDetailScreen(restaurant: widget.restaurant),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = 0.0;
                const end = 1.0;
                const curve = Curves.easeInOutCubic;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return FadeTransition(
                  opacity: animation.drive(tween),
                  child: child,
                );
              },
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  // Clean image with rounded corners (Glovo style)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: RestaurantCardImage(
                      imageUrl: widget.restaurant.imageUrl,
                      height: 180,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  
                  // Ratings badge (top-left)
                  if (widget.restaurant.averageRating > 0)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                            const SizedBox(width: 4),
                            Text(
                              widget.restaurant.averageRating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Simple favorite button (Glovo style)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: widget.onFavoriteToggle,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: widget.isFavorite ? Colors.red.shade600 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Clean Glovo-style info section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Restaurant name
                    Text(
                      widget.restaurant.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    
                    // Single line with all info (Glovo style)
                    Row(
                      children: [
                        // Rating with stars
                        if (widget.restaurant.averageRating > 0) ...[
                          Icon(Icons.star, size: 15, color: Colors.amber.shade600),
                          const SizedBox(width: 4),
                          Text(
                            widget.restaurant.averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('(${(widget.restaurant.averageRating * 20).toInt()}+)', 
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          const SizedBox(width: 4),
                          Text('•', style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(width: 4),
                        ],
                        
                        // Distance
                        Text(
                          widget.distance ?? '...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('•', style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(width: 4),
                        
                        // Delivery time
                        Text(
                          '${widget.restaurant.deliveryTime}-${widget.restaurant.deliveryTime + 10} min',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('•', style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(width: 4),
                        
                        // Delivery fee badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.restaurant.deliveryFee == 0 
                                ? Colors.amber.shade100 
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.restaurant.deliveryFee == 0 
                                    ? Icons.currency_bitcoin 
                                    : Icons.attach_money,
                                size: 12,
                                color: widget.restaurant.deliveryFee == 0 
                                    ? Colors.amber.shade900 
                                    : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                widget.restaurant.deliveryFee == 0 ? 'UGX Free' : 'UGX ${widget.restaurant.deliveryFee.toInt()}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: widget.restaurant.deliveryFee == 0 
                                      ? Colors.amber.shade900 
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Shimmer loading effect
class ShimmerLoader extends StatefulWidget {
  final Widget child;
  
  const ShimmerLoader({super.key, required this.child});
  
  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + (_controller.value * 2), 0.0),
              end: Alignment(1.0 + (_controller.value * 2), 0.0),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}