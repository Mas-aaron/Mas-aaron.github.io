class DietaryPreference {
  final int id;
  final String name;
  final String description;

  DietaryPreference({
    required this.id,
    required this.name,
    required this.description,
  });

  factory DietaryPreference.fromJson(Map<String, dynamic> json) {
    return DietaryPreference(
      id: json['id'],
      name: json['name'],
      description: json['description'],
    );
  }
}
