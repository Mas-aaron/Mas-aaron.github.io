import 'package:food_delivery_app/constants.dart';

class Restaurant {
  final int id;
  final String name;
  final String address;
  final String phoneNumber;
  final String? imageUrl;
  final double? distance;
  final double averageRating;
  final int deliveryTime;
  final double deliveryFee;
  final String cuisineType;
  final double lat;
  final double lng;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.phoneNumber,
    this.imageUrl,
    this.distance,
    required this.averageRating,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.cuisineType,
    required this.lat,
    required this.lng,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    String? imageUrl = json['image_url'];
    if (imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = '$baseUrl$imageUrl';
    }

    return Restaurant(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Restaurant',
      address: json['address'] ?? 'No address',
      phoneNumber: json['phone_number'] ?? 'No phone number',
      imageUrl: imageUrl,
      distance: (json['distance'] as num?)?.toDouble(),
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      deliveryTime: json['delivery_time'] ?? 30,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      cuisineType: json['cuisine_type'] ?? 'Various',
      lat: double.tryParse(json['lat']?.toString() ?? '0.0') ?? 0.0,
      lng: double.tryParse(json['lng']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

