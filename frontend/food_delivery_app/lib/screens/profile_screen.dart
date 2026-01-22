import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/customer_profile.dart';
import 'package:food_delivery_app/models/dietary_preference.dart';
import 'package:food_delivery_app/models/user_address.dart';
import 'package:food_delivery_app/services/profile_service.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lottie/lottie.dart';
import '../providers/auth_provider.dart';
import 'loyalty_dashboard_screen.dart';
import 'order_history_screen.dart';
import 'faq_screen.dart';
import 'edit_profile_screen.dart';
import 'promo_codes_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  Future<CustomerProfile>? _profileFuture;
  Future<List<UserAddress>>? _addressesFuture;
  Future<List<DietaryPreference>>? _allPreferencesFuture;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
    
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadProfileData() {
    _profileFuture = _profileService.getCustomerProfile();
    _addressesFuture = _profileService.getAddresses();
    _allPreferencesFuture = _profileService.getDietaryPreferences();
    setState(() {});
  }

  Future<void> _refreshProfileData() async {
    final newProfileFuture = _profileService.getCustomerProfile();
    final newAddressesFuture = _profileService.getAddresses();
    final newAllPreferencesFuture = _profileService.getDietaryPreferences();

    setState(() {
      _profileFuture = newProfileFuture;
      _addressesFuture = newAddressesFuture;
      _allPreferencesFuture = newAllPreferencesFuture;
    });

    await Future.wait([newProfileFuture, newAddressesFuture, newAllPreferencesFuture]);
  }

  Future<void> _showAddressFormDialog({UserAddress? address}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: const Color.fromRGBO(0, 0, 0, 0.5),
            child: GestureDetector(
              onTap: () {},
              child: DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.5,
                maxChildSize: 0.9,
                builder: (_, controller) {
                  return _AddressFormSheet(
                    address: address,
                    onSave: _loadProfileData,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: ModalRoute.of(context)!.animation!,
            curve: Curves.easeOutBack,
          ),
          child: AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  try {
                    await _profileService.deleteCurrentUser();
                    if (!mounted) return;
                    await Provider.of<AuthProvider>(context, listen: false).logout();
                    if (!mounted) return;
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (Route<dynamic> route) => false,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FutureBuilder<CustomerProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingScreen();
          } else if (snapshot.hasError) {
            return _buildErrorScreen(snapshot.error.toString());
          } else if (!snapshot.hasData) {
            return _buildEmptyState();
          }

          final profile = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refreshProfileData,
            color: Colors.orange,
            backgroundColor: Colors.white,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  backgroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background: _buildProfileHeader(profile),
                  ),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                EditProfileScreen(profile: profile),
                            transitionsBuilder:
                                (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 1),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              );
                            },
                          ),
                        ).then((_) => _loadProfileData());
                      },
                    ),
                  ],
                ),
                SliverList(
                  delegate: SliverChildListDelegate([
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          _buildFeaturesSection(),
                          _buildSettingsSection(),
                          _buildVersionInfo(),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(CustomerProfile profile) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF8A00),
            Color(0xFFFF5E00),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final avatarRadius = (constraints.maxHeight * 0.22).clamp(32.0, 50.0);
          final avatarIconSize = (avatarRadius * 1.2).clamp(36.0, 60.0);
          final titleFontSize = (constraints.maxHeight * 0.10).clamp(18.0, 24.0);
          final subtitleFontSize = (constraints.maxHeight * 0.055).clamp(12.0, 14.0);
          final topPadding = MediaQuery.of(context).padding.top;

          return Padding(
            padding: EdgeInsets.only(top: topPadding * 0.25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    // Add photo upload functionality
                  },
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'profile_avatar',
                        child: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Icon(
                            Icons.person,
                            size: avatarIconSize,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.orange,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: (constraints.maxHeight * 0.06).clamp(8.0, 16.0)),
                Text(
                  profile.user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.history,
            title: 'My Orders',
            subtitle: 'Track and view order history',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OrderHistoryScreen(),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.person_outline,
            title: 'My Information',
            subtitle: 'Manage your personal details',
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const EditProfileScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                ),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.share,
            title: 'Share and Earn!',
            subtitle: 'Invite friends and get rewards',
            onTap: () async {
              final box = context.findRenderObject() as RenderBox?;
              await Share.share(
                'Join me on FoodExpress! Use my code FOODIE50 for 50% off your first order!',
                sharePositionOrigin:
                    box!.localToGlobal(Offset.zero) & box.size,
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.stars_rounded,
            title: 'Premium Membership',
            subtitle: 'Get free delivery and exclusive offers',
            trailing: Chip(
              label: const Text(
                'TRY FREE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              backgroundColor: Colors.orange.withOpacity(0.1),
              side: BorderSide.none,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const LoyaltyDashboardScreen(),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.local_offer,
            title: 'Promo Codes',
            subtitle: 'View and apply discount codes',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PromoCodesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'F.A.Q.',
            subtitle: 'Frequently asked questions',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const FAQScreen(),
                ),
              );
            },
          ),
          _buildDivider(),
          _buildMenuItem(
            icon: Icons.delete_outline,
            title: 'Delete My Account and Data',
            subtitle: 'Permanently remove your account',
            titleColor: Colors.red,
            onTap: _showDeleteAccountDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: titleColor ?? Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: Colors.grey[200],
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'App Version',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '9.22.0 (73409)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login', (Route<dynamic> route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, size: 20),
                SizedBox(width: 8),
                Text('Log Out'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Lottie.asset(
        'assets/animations/food_loading.json', // Add your Lottie animation
        width: 200,
        height: 200,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/error.json', // Add error animation
            width: 150,
            height: 150,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.orange,
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            error,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadProfileData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/empty_profile.json',
            width: 200,
            height: 200,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.person_outline,
                size: 96,
                color: Colors.grey,
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'No profile data found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _loadProfileData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Load Profile'),
          ),
        ],
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  final UserAddress? address;
  final VoidCallback onSave;

  const _AddressFormSheet({this.address, required this.onSave});

  @override
  __AddressFormSheetState createState() => __AddressFormSheetState();
}

class __AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();
  final TextEditingController _addressLine1Controller = TextEditingController();
  final TextEditingController _addressLine2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      final address = widget.address!;
      _addressLine1Controller.text = address.addressLine1;
      _addressLine2Controller.text = address.addressLine2 ?? '';
      _cityController.text = address.city;
      _stateController.text = address.stateProvince;
      _postalCodeController.text = address.postalCode;
      _countryController.text = address.country;
      _isDefault = address.isDefault;
    } else {
      _countryController.text = 'USA';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 20),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.orange, size: 24),
                const SizedBox(width: 10),
                Text(
                  widget.address == null ? 'Add New Address' : 'Edit Address',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildTextField(
                    controller: _addressLine1Controller,
                    label: 'Address Line 1',
                    icon: Icons.home,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _addressLine2Controller,
                    label: 'Address Line 2 (Optional)',
                    icon: Icons.apartment,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    icon: Icons.location_city,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _stateController,
                    label: 'State/Province',
                    icon: Icons.map,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _postalCodeController,
                    label: 'Postal Code',
                    icon: Icons.local_post_office,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _countryController,
                    label: 'Country',
                    icon: Icons.public,
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('Set as default address'),
                    value: _isDefault,
                    onChanged: (value) {
                      setState(() {
                        _isDefault = value;
                      });
                    },
                    activeColor: Colors.orange,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Address'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange),
        ),
      ),
      validator: (value) {
        if (label != 'Address Line 2 (Optional)' && (value == null || value.isEmpty)) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final newAddress = UserAddress(
        id: widget.address?.id ?? 0,
        addressLine1: _addressLine1Controller.text,
        addressLine2: _addressLine2Controller.text.isNotEmpty
            ? _addressLine2Controller.text
            : null,
        city: _cityController.text,
        stateProvince: _stateController.text,
        postalCode: _postalCodeController.text,
        country: _countryController.text,
        isDefault: _isDefault,
      );

      if (widget.address == null) {
        await _profileService.addAddress(newAddress);
      } else {
        await _profileService.updateAddress(widget.address!.id, newAddress);
      }

      widget.onSave();
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Address saved successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save address: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}