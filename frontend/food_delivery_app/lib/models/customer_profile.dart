import 'package:food_delivery_app/models/dietary_preference.dart';

// A simple user model for the profile
class ProfileUser {
  final int id;
  final String username;
  final String email;

  ProfileUser({required this.id, required this.username, required this.email});

  factory ProfileUser.fromJson(Map<String, dynamic> json) {
    return ProfileUser(
      id: json['id'],
      username: json['username'],
      email: json['email'],
    );
  }
}

class CustomerProfile {
  final ProfileUser user;
  final List<DietaryPreference> dietaryPreferences;

  CustomerProfile({
    required this.user,
    required this.dietaryPreferences,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    var preferencesList = json['dietary_preferences'] as List;
    List<DietaryPreference> preferences = preferencesList
        .map((i) => DietaryPreference.fromJson(i))
        .toList();

    return CustomerProfile(
      user: ProfileUser.fromJson(json['user']),
      dietaryPreferences: preferences,
    );
  }
}
