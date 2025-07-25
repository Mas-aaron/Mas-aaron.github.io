class Restaurant {
  final int id;
  final String name;
  final String address;
  final String phoneNumber;
  final String? imageUrl;
  final double? distance;
  final double rating;
  final int deliveryTime;
  final double deliveryFee;
  final String cuisineType;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.phoneNumber,
    this.imageUrl,
    this.distance,
    required this.rating,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.cuisineType,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      phoneNumber: json['phone_number'],
      imageUrl: json['image_url'],
      distance: (json['distance'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      deliveryTime: json['delivery_time'] ?? 30,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      cuisineType: json['cuisine_type'] ?? 'Various',
    );
  }
}
