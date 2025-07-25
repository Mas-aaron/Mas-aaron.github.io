import 'menu_item.dart';

class MenuCategory {
  final int id;
  final String name;
  final List<MenuItem> items;

  MenuCategory({
    required this.id,
    required this.name,
    required this.items,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    var itemsList = json['items'] as List;
    List<MenuItem> menuItems = itemsList.map((i) => MenuItem.fromJson(i)).toList();

    return MenuCategory(
      id: json['id'],
      name: json['name'],
      items: menuItems,
    );
  }
}
