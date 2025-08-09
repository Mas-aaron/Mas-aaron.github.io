import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_dashboard_new/models/restaurant.dart';
import 'package:restaurant_dashboard_new/providers/theme_provider.dart';
import 'package:restaurant_dashboard_new/services/restaurant_service.dart';
import 'package:restaurant_dashboard_new/screens/edit_restaurant_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  static const routeName = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Restaurant> _restaurantFuture;
  final RestaurantService _restaurantService = RestaurantService();

  @override
  void initState() {
    super.initState();
    _restaurantFuture = _restaurantService.getRestaurantProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<Restaurant>(
              future: _restaurantFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('No restaurant profile found.'));
                }

                final restaurant = snapshot.data!;

                return ListView(
                  children: [
                    _buildSettingsSection(
                      title: 'Profile Settings',
                      children: [
                        _buildSettingsTile(
                          icon: Icons.store, 
                          title: 'Restaurant Information', 
                          subtitle: '${restaurant.name} - ${restaurant.address}',
                          onTap: () async {
                            final result = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (context) => EditRestaurantProfileScreen(restaurant: restaurant),
                              ),
                            );
                            if (result == true) {
                              setState(() {
                                _restaurantFuture = _restaurantService.getRestaurantProfile();
                              });
                            }
                          },
                        ),
                        _buildSettingsTile(icon: Icons.phone, title: 'Contact', subtitle: '${restaurant.phoneNumber} - ${restaurant.email}'),
                      ],
                    ),
                    _buildSettingsSection(
                      title: 'Notification Settings',
                      children: [
                        _buildSwitchTile(icon: Icons.notifications, title: 'Push Notifications', subtitle: 'Receive alerts for new orders', value: true),
                        _buildSwitchTile(icon: Icons.email, title: 'Email Notifications', subtitle: 'Get order summaries and updates via email', value: false),
                      ],
                    ),
                    _buildSettingsSection(
                      title: 'Application Settings',
                      children: [
                        Consumer<ThemeProvider>(
                          builder: (context, themeProvider, child) {
                            return SwitchListTile(
                              secondary: const Icon(Icons.dark_mode, color: Colors.orangeAccent),
                              title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Enable a darker theme for the app', style: TextStyle(color: Colors.grey[600])),
                              value: themeProvider.themeMode == ThemeMode.dark,
                              onChanged: (bool value) {
                                themeProvider.toggleTheme(value);
                              },
                              activeColor: Colors.orange,
                            );
                          },
                        ),
                        _buildSettingsTile(icon: Icons.language, title: 'Language', subtitle: 'English'),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.orangeAccent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required String subtitle, required bool value}) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.orangeAccent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      value: value,
      onChanged: (bool newValue) {
        // TODO: Add state management logic here
      },
      activeColor: Colors.orange,
    );
  }
}
