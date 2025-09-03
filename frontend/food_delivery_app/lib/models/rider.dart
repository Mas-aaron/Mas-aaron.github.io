class Rider {
  final int? id;
  final String name;
  final String? phoneNumber;
  final String? profileImage;
  final double? rating;

  Rider({
    this.id,
    required this.name,
    this.phoneNumber,
    this.profileImage,
    this.rating,
  });

  factory Rider.fromJson(Map<String, dynamic> json) {
    // Handle both API response formats
    String riderName = 'Rider';
    if (json['name'] != null) {
      riderName = json['name'];
    } else if (json['first_name'] != null || json['last_name'] != null) {
      final firstName = json['first_name'] ?? '';
      final lastName = json['last_name'] ?? '';
      riderName = '$firstName $lastName'.trim();
      if (riderName.isEmpty) riderName = 'Rider';
    }

    return Rider(
      id: json['id'] as int?,
      name: riderName,
      phoneNumber: json['phone_number'],
      profileImage: json['profile_image'],
      rating: json['rating']?.toDouble(),
    );
  }
}
