import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/customer_profile.dart';
import 'package:food_delivery_app/models/dietary_preference.dart';
import 'package:food_delivery_app/models/user_address.dart';
import 'package:food_delivery_app/services/profile_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  Future<CustomerProfile>? _profileFuture;
  Future<List<UserAddress>>? _addressesFuture;
  Future<List<DietaryPreference>>? _allPreferencesFuture;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
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

    // Wait for all futures to complete for the refresh indicator
    await Future.wait([newProfileFuture, newAddressesFuture, newAllPreferencesFuture]);
  }

  Future<void> _showAddressFormDialog({UserAddress? address}) async {
    final formKey = GlobalKey<FormState>();
    final addressLine1Controller = TextEditingController(text: address?.addressLine1);
    final addressLine2Controller = TextEditingController(text: address?.addressLine2);
    final cityController = TextEditingController(text: address?.city);
    final stateController = TextEditingController(text: address?.stateProvince);
    final postalCodeController = TextEditingController(text: address?.postalCode);
    final countryController = TextEditingController(text: address?.country ?? 'USA');
    bool isDefault = address?.isDefault ?? false;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(address == null ? 'Add New Address' : 'Edit Address'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(controller: addressLine1Controller, decoration: const InputDecoration(labelText: 'Address Line 1'), validator: (value) => value!.isEmpty ? 'Required' : null),
                      TextFormField(controller: addressLine2Controller, decoration: const InputDecoration(labelText: 'Address Line 2 (Optional)')),
                      TextFormField(controller: cityController, decoration: const InputDecoration(labelText: 'City'), validator: (value) => value!.isEmpty ? 'Required' : null),
                      TextFormField(controller: stateController, decoration: const InputDecoration(labelText: 'State/Province'), validator: (value) => value!.isEmpty ? 'Required' : null),
                      TextFormField(controller: postalCodeController, decoration: const InputDecoration(labelText: 'Postal Code'), validator: (value) => value!.isEmpty ? 'Required' : null),
                      TextFormField(controller: countryController, decoration: const InputDecoration(labelText: 'Country'), validator: (value) => value!.isEmpty ? 'Required' : null),
                      CheckboxListTile(
                        title: const Text("Set as default"),
                        value: isDefault,
                        onChanged: (newValue) {
                          setState(() {
                            isDefault = newValue!;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      )
                    ],
                  ),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newAddress = UserAddress(
                    id: address?.id ?? 0,
                    addressLine1: addressLine1Controller.text,
                    addressLine2: addressLine2Controller.text.isNotEmpty ? addressLine2Controller.text : null,
                    city: cityController.text,
                    stateProvince: stateController.text,
                    postalCode: postalCodeController.text,
                    country: countryController.text,
                    isDefault: isDefault,
                  );

                  try {
                    if (address == null) {
                      await _profileService.addAddress(newAddress);
                    } else {
                      await _profileService.updateAddress(address.id, newAddress);
                    }
                    Navigator.of(context).pop();
                    _loadProfileData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save address: $e')));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProfileData,
          ),
        ],
      ),
      body: FutureBuilder<CustomerProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No profile data found.'));
          }

          final profile = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refreshProfileData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildProfileHeader(profile),
                const SizedBox(height: 32),
                _buildAddressesSection(),
                const SizedBox(height: 16),
                _buildDietaryPreferencesSection(profile),
                const SizedBox(height: 32),
                _buildLogoutButton(context),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _buildProfileHeader(CustomerProfile profile) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.orange[100],
          child: const Icon(Icons.person, size: 50, color: Colors.orange),
        ),
        const SizedBox(height: 16),
        Text(
          profile.user.username,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          profile.user.email,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAddressesSection() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.location_on, color: Colors.orange),
        title: const Text('Saved Addresses'),
        children: [
          FutureBuilder<List<UserAddress>>(
            future: _addressesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Error: ${snapshot.error}'),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No saved addresses.'),
                );
              }

              final addresses = snapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: addresses.length,
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  return ListTile(
                    title: Text(address.addressLine1),
                    subtitle: Text('${address.city}, ${address.postalCode}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () async {
                        try {
                          await _profileService.deleteAddress(address.id);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address deleted')));
                          _loadProfileData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete address: $e')));
                        }
                      },
                    ),
                    onTap: () => _showAddressFormDialog(address: address),
                  );
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add New Address'),
              onPressed: () => _showAddressFormDialog(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryPreferencesSection(CustomerProfile profile) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.restaurant_menu, color: Theme.of(context).primaryColor),
        title: const Text('Dietary Preferences'),
        children: [
          FutureBuilder<List<DietaryPreference>>(
            future: _allPreferencesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: ${snapshot.error}'),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No dietary preferences available.'),
                );
              }

              final allPreferences = snapshot.data!;
              final userPreferenceIds = profile.dietaryPreferences.map((dp) => dp.id).toSet();

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: allPreferences.map((preference) {
                    final isSelected = userPreferenceIds.contains(preference.id);
                    return FilterChip(
                      label: Text(preference.name),
                      selected: isSelected,
                      onSelected: (bool selected) async {
                        final newPreferenceIds = List<int>.from(userPreferenceIds);
                        if (selected) {
                          newPreferenceIds.add(preference.id);
                        } else {
                          newPreferenceIds.remove(preference.id);
                        }
                        try {
                          await _profileService.updateCustomerProfile(newPreferenceIds);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preferences updated!'), duration: Duration(seconds: 1)));
                          _loadProfileData(); // Refresh to show updated state
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: () {
        Provider.of<AuthProvider>(context, listen: false).logout();
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
      },
      child: const Text('Logout'),
    );
  }
}
