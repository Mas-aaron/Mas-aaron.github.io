class ModifierGroup {
  final int id;
  final String name;
  final bool required;
  final List<Modifier> modifiers;

  ModifierGroup({
    required this.id,
    required this.name,
    required this.required,
    required this.modifiers,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    return ModifierGroup(
      id: json['id'],
      name: json['name'],
      required: json['required'],
      modifiers: (json['modifiers'] as List?)?.map((m) => Modifier.fromJson(m)).toList() ?? [],
    );
  }
}

class Modifier {
  final int id;
  final String name;
  final double priceDelta;

  Modifier({required this.id, required this.name, required this.priceDelta});

  factory Modifier.fromJson(Map<String, dynamic> json) {
    return Modifier(
      id: json['id'],
      name: json['name'],
      priceDelta: (json['price_delta'] as num).toDouble(),
    );
  }
}
