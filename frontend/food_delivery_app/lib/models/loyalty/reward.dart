class Reward {
  final int id;
  final String name;
  final int pointsRequired;
  final String description;
  final String? image;

  Reward({
    required this.id,
    required this.name,
    required this.pointsRequired,
    required this.description,
    this.image,
  });

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id'],
      name: json['name'],
      pointsRequired: json['points_required'],
      description: json['description'],
      image: json['image'],
    );
  }
}
