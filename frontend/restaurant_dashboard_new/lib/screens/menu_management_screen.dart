import 'package:flutter/material.dart';
import '../services/menu_service.dart';
import '../models/menu_item.dart';
import '../models/menu_category.dart';
import 'package:image_picker/image_picker.dart';
import 'package:restaurant_dashboard_new/utils/currency_formatter.dart';



class MenuManagementScreen extends StatefulWidget {
  static const routeName = '/menu-management';

  const MenuManagementScreen({super.key});

  @override
  _MenuManagementScreenState createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final MenuService _menuService = MenuService();
  late Future<List<MenuItem>> _menuItemsFuture;
  List<MenuCategory> _categories = [];
  int? _selectedCategoryId;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _menuItemsFuture = _menuService.getMenu();
    _fetchCategories();
  }

  void _refreshMenuItems() {
    setState(() {
      _menuItemsFuture = _menuService.getMenu();
    });
  }

  Future<void> _fetchCategories() async {
    try {
      final categories = await _menuService.getMenuCategories();
      setState(() {
        _categories = categories ?? [];
        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id;
        } else {
          _selectedCategoryId = null;
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _categories = [];
        _selectedCategoryId = null;
        _isLoadingCategories = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<MenuItem>>(
              future: _menuItemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No menu items found.'));
                }

                final menuItems = snapshot.data!;

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300, // Max width for each item
                    childAspectRatio: 2 / 2.5, // Aspect ratio for each item
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return _MenuItemCard(item: item, onEdit: () => _showEditMenuItemDialog(item), onDelete: () => _deleteItem(item.id));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      spacing: 16,
      children: [
        const Text('Menu Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            ElevatedButton.icon(
              onPressed: _showManageCategoriesDialog,
              icon: const Icon(Icons.category),
              label: const Text('Manage Categories'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showAddMenuItemDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Menu Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _deleteItem(int id) async {
    try {
      await _menuService.deleteMenuItem(id);
      _refreshMenuItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete item: $e')));
      }
    }
  }

      void _showEditMenuItemDialog(MenuItem item) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: item.name);
    final descriptionController = TextEditingController(text: item.description);
    final priceController = TextEditingController(text: CurrencyFormatter.formatUGX(item.price));
    XFile? imageFile;
    int? selectedCategoryId = item.category;
    bool isAvailable = item.isAvailable;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Menu Item'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              Future<void> pickImage() async {
                final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                                    setState(() {
                    imageFile = pickedFile;
                  });
                }
              }

              return SizedBox(
                width: 400, // Constrain width to prevent layout errors
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                                                                                                if (imageFile != null)
                          Image.network(imageFile!.path, height: 150, fit: BoxFit.cover)
                        else if (item.image != null && item.image!.isNotEmpty)
                          Image.network(item.image!, height: 150, fit: BoxFit.cover),
                        ElevatedButton(onPressed: pickImage, child: const Text('Change Image')),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                          validator: (value) => value!.isEmpty ? 'Enter a name' : null,
                        ),
                        TextFormField(
                          controller: descriptionController,
                          decoration: const InputDecoration(labelText: 'Description'),
                          validator: (value) => value!.isEmpty ? 'Enter a description' : null,
                        ),
                        TextFormField(
                          controller: priceController,
                          decoration: const InputDecoration(labelText: 'Price (UGX)'),
                          keyboardType: TextInputType.number,
                          validator: (value) => value!.isEmpty ? 'Enter a price' : null,
                        ),
                        _categories.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  border: Border.all(color: Colors.orange[200]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.category, color: Colors.orange[600], size: 32),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No categories available',
                                      style: TextStyle(
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Please create a category first using "Manage Categories"',
                                      style: TextStyle(
                                        color: Colors.orange[600],
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : DropdownButtonFormField<int>(
                                value: selectedCategoryId,
                                items: _categories.map((MenuCategory category) {
                                  return DropdownMenuItem<int>(
                                    value: category.id,
                                    child: Text(category.name),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    selectedCategoryId = newValue;
                                  });
                                },
                                decoration: const InputDecoration(labelText: 'Category'),
                                validator: (value) => value == null ? 'Select a category' : null,
                              ),
                        SwitchListTile(
                          title: const Text('Available'),
                          value: isAvailable,
                          onChanged: (bool value) {
                            setState(() {
                              isAvailable = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await _menuService.updateMenuItem(
                      item.id,
                      nameController.text,
                      descriptionController.text,
                      CurrencyFormatter.parseUGX(priceController.text).toDouble(),
                      selectedCategoryId!,
                      isAvailable,
                      imageFile,
                    );
                    if (mounted) Navigator.of(context).pop();
                    _refreshMenuItems();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update item: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showManageCategoriesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void refreshCategories() {
              _fetchCategories().then((_) => setState(() {}));
            }

            return AlertDialog(
              title: const Text('Manage Categories'),
              content: SizedBox(
                width: 400, // Constrain width
                child: _isLoadingCategories
                    ? const Center(child: CircularProgressIndicator())
                    : _categories.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.category, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No categories yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create your first category to start organizing your menu items.',
                                  style: TextStyle(color: Colors.grey[500]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _categories.map((category) {
                                return ListTile(
                                  title: Text(category.name),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _showEditCategoryDialog(category, refreshCategories),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _showDeleteCategoryConfirmation(category, refreshCategories),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nameController = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Add Category'),
                        content: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Category Name'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.isNotEmpty) {
                                try {
                                  await _menuService.addMenuCategory(nameController.text);
                                  if (mounted) Navigator.of(context).pop();
                                  refreshCategories();
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to add category: $e')),
                                    );
                                  }
                                }
                              }
                            },
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Add Category'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditCategoryDialog(MenuCategory category, VoidCallback onUpdate) {
    final nameController = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                try {
                  await _menuService.updateMenuCategory(category.id, nameController.text);
                  if (mounted) Navigator.of(context).pop();
                  onUpdate();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update category: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryConfirmation(MenuCategory category, VoidCallback onUpdate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete the category "${category.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _menuService.deleteMenuCategory(category.id);
                if (mounted) Navigator.of(context).pop();
                onUpdate();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete category: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

      void _showAddMenuItemDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController();
    XFile? imageFile;
    int? selectedCategoryId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          Future<void> pickImage() async {
            final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
            if (pickedFile != null) {
                            setState(() {
                imageFile = pickedFile;
              });
            }
          }

          return AlertDialog(
            title: const Text('Add New Menu Item'),
            content: SizedBox(
              width: 400, // Constrain width to prevent layout errors
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                                                                  if (imageFile != null)
                        Image.network(imageFile!.path, height: 150, fit: BoxFit.cover)
                      else
                        Container(
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(child: Text('No Image Selected')),
                        ),
                      ElevatedButton(onPressed: pickImage, child: const Text('Select Image')),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => value!.isEmpty ? 'Enter a name' : null,
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        validator: (value) => value!.isEmpty ? 'Enter a description' : null,
                      ),
                      TextFormField(
                        controller: priceController,
                        decoration: const InputDecoration(labelText: 'Price (UGX)'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty ? 'Enter a price' : null,
                      ),
                      _categories.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                border: Border.all(color: Colors.orange[200]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.category, color: Colors.orange[600], size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No categories available',
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Please create a category first using "Manage Categories"',
                                    style: TextStyle(
                                      color: Colors.orange[600],
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<int>(
                              value: selectedCategoryId,
                              items: _categories.map((MenuCategory category) {
                                return DropdownMenuItem<int>(
                                  value: category.id,
                                  child: Text(category.name),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  selectedCategoryId = newValue;
                                });
                              },
                              decoration: const InputDecoration(labelText: 'Category'),
                              validator: (value) => value == null ? 'Select a category' : null,
                            ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (_categories.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please create at least one category before adding menu items.')),
                    );
                    return;
                  }
                  if (formKey.currentState!.validate()) {
                    if (selectedCategoryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a category first.')),
                      );
                      return;
                    }
                    try {
                      await _menuService.addMenuItem(
                        nameController.text,
                        descriptionController.text,
                        CurrencyFormatter.parseUGX(priceController.text).toDouble(),
                        selectedCategoryId!,
                        imageFile,
                      );
                      if (mounted) Navigator.of(context).pop();
                      _refreshMenuItems();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add item: $e')),
                        );
                      }
                    }
                  }
                },
                child: const Text('Add Item'),
              ),
            ],
          );
        });
      },
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MenuItemCard({required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            child: Image.network(
              item.image ?? '', // Use real image URL
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.grey[400],
                    size: 40,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(item.description, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Text(CurrencyFormatter.formatUGX(item.price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const Spacer(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: onEdit),
                IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
