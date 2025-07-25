import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../models/menu_item.dart';
import '../models/modifier_group.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  String? authToken;
  int selectedRestaurantId = 1; // Default, replace with dynamic selection
  late ApiService api;
  List<MenuItem> menuItems = [];
  List<ModifierGroup> modifierGroups = [];
  bool isLoading = false;
  String? uploadStatus;

  @override
  void initState() {
    super.initState();
    api = ApiService(baseUrl: 'http://10.0.2.2:8000/api', authToken: authToken);
    fetchMenu();
    fetchModifiers();
  }

  Future<void> fetchMenu() async {
    setState(() => isLoading = true);
    try {
      // TODO: Replace 1 with actual restaurant ID
      final items = await api.fetchMenuItems(1);
      setState(() {
        menuItems = items.map((j) => MenuItem.fromJson(j)).toList();
      });
    } catch (e) {
      setState(() { uploadStatus = 'Failed to load menu: $e'; });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchModifiers() async {
    try {
      final groups = await api.fetchModifierGroups();
      setState(() {
        modifierGroups = groups.map((j) => ModifierGroup.fromJson(j)).toList();
      });
    } catch (e) {
      // Optionally handle error
    }
  }

  Future<void> pickAndUploadCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() { uploadStatus = 'Uploading...'; });
      try {
        // TODO: Replace 1 with actual restaurant ID
        final res = await api.uploadMenuCsv(restaurantId: 1, file: file);
        setState(() { uploadStatus = 'Upload complete: ${res['created']} created, ${res['updated']} updated'; });
        fetchMenu();
      } catch (e) {
        setState(() { uploadStatus = 'Upload failed: $e'; });
      }
    }
  }

  void openModifierGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => ModifierGroupDialog(
        modifierGroups: modifierGroups,
        onRefresh: fetchModifiers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => MenuItemCreateDialog(
              modifierGroups: modifierGroups,
              restaurantId: selectedRestaurantId,
              api: api,
              onSave: () => fetchMenu(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Menu Item'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Authentication and Restaurant Selection
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'API Token',
                    hintText: 'Paste your auth token',
                  ),
                  onChanged: (val) {
                    setState(() {
                      authToken = val;
                      api = ApiService(baseUrl: 'http://10.0.2.2:8000/api', authToken: authToken);
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: selectedRestaurantId,
                items: [1, 2, 3].map((id) => DropdownMenuItem<int>(
                  value: id,
                  child: Text('Restaurant $id'),
                )).toList(),
                onChanged: (id) {
                  if (id != null) {
                    setState(() { selectedRestaurantId = id; });
                    fetchMenu();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Menu Management', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          // CSV Upload Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.upload_file, color: Colors.orange),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Bulk Upload Menu Items (CSV)', style: TextStyle(fontWeight: FontWeight.bold))),
                  ElevatedButton(
                    onPressed: pickAndUploadCsv,
                    child: const Text('Upload'),
                  ),
                ],
              ),
            ),
          ),
          if (uploadStatus != null) ...[
            const SizedBox(height: 8),
            Text(uploadStatus!, style: TextStyle(color: uploadStatus!.contains('fail') ? Colors.red : Colors.green)),
          ],
          const SizedBox(height: 24),
          // Menu Items List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : menuItems.isEmpty
                    ? const Center(child: Text('No menu items found.'))
                    : ListView.builder(
                        itemCount: menuItems.length,
                        itemBuilder: (context, idx) {
                          final item = menuItems[idx];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(backgroundColor: Colors.orange[100], child: const Icon(Icons.fastfood, color: Colors.orange)),
                              title: Text(item.name),
                              subtitle: Row(
                                children: [
                                  if (item.availableBreakfast) Chip(label: const Text('Breakfast'), backgroundColor: Colors.orange[50]),
                                  if (item.availableLunch) ...[
                                    const SizedBox(width: 4),
                                    Chip(label: const Text('Lunch'), backgroundColor: Colors.orange[50]),
                                  ],
                                  if (item.availableDinner) ...[
                                    const SizedBox(width: 4),
                                    Chip(label: const Text('Dinner'), backgroundColor: Colors.orange[50]),
                                  ],
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => MenuItemEditDialog(
                                      item: item,
                                      modifierGroups: modifierGroups,
                                      restaurantId: selectedRestaurantId,
                                      api: api,
                                      onSave: () => fetchMenu(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 24),
          // Modifier Groups Management
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.orange),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Manage Modifier Groups (e.g. Spice Level, Add-ons)', style: TextStyle(fontWeight: FontWeight.bold))),
                  ElevatedButton(
                    onPressed: openModifierGroupDialog,
                    child: const Text('Manage'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MenuItemEditDialog extends StatefulWidget {
  final MenuItem item;
  final List<ModifierGroup> modifierGroups;
  final int restaurantId;
  final ApiService api;
  final VoidCallback onSave;
  const MenuItemEditDialog({required this.item, required this.modifierGroups, required this.restaurantId, required this.api, required this.onSave, super.key});
  @override
  State<MenuItemEditDialog> createState() => _MenuItemEditDialogState();
}

class _MenuItemEditDialogState extends State<MenuItemEditDialog> {
  late bool breakfast;
  late bool lunch;
  late bool dinner;
  late List<int> selectedModifierGroups;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    breakfast = widget.item.availableBreakfast;
    lunch = widget.item.availableLunch;
    dinner = widget.item.availableDinner;
    selectedModifierGroups = List<int>.from(widget.item.modifierGroupIds);
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.api.updateMenuItem(
        restaurantId: widget.restaurantId,
        menuItemId: widget.item.id,
        data: {
          'available_breakfast': breakfast,
          'available_lunch': lunch,
          'available_dinner': dinner,
          'modifier_groups': selectedModifierGroups,
        },
      );
      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Menu Item'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Checkbox(value: breakfast, onChanged: (v) => setState(() => breakfast = v ?? false)),
                const Text('Breakfast'),
                Checkbox(value: lunch, onChanged: (v) => setState(() => lunch = v ?? false)),
                const Text('Lunch'),
                Checkbox(value: dinner, onChanged: (v) => setState(() => dinner = v ?? false)),
                const Text('Dinner'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Modifier Groups:'),
            ...widget.modifierGroups.map((mg) => CheckboxListTile(
                  value: selectedModifierGroups.contains(mg.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        selectedModifierGroups.add(mg.id);
                      } else {
                        selectedModifierGroups.remove(mg.id);
                      }
                    });
                  },
                  title: Text(mg.name),
                  controlAffinity: ListTileControlAffinity.leading,
                )),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: saving ? null : save,
          child: saving ? const CircularProgressIndicator() : const Text('Save'),
        ),
      ],
    );
  }
}

class ModifierGroupDialog extends StatefulWidget {
  final List<ModifierGroup> modifierGroups;
  final VoidCallback onRefresh;
  const ModifierGroupDialog({required this.modifierGroups, required this.onRefresh, super.key});
  @override
  State<ModifierGroupDialog> createState() => _ModifierGroupDialogState();
}

class _ModifierGroupDialogState extends State<ModifierGroupDialog> {
  bool creating = false;
  String? newName;
  bool newRequired = false;
  ModifierGroup? editing;
  String? editName;
  bool editRequired = false;
  bool saving = false;

  ApiService get api => (context.findAncestorStateOfType<_MenuManagementScreenState>()?.api)!;

  Future<void> createGroup() async {
    setState(() => saving = true);
    try {
      await api.createModifierGroup({
        'name': newName,
        'required': newRequired,
      });
      widget.onRefresh();
      setState(() { creating = false; newName = null; newRequired = false; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally { setState(() => saving = false); }
  }

  Future<void> saveEdit() async {
    if (editing == null) return;
    setState(() => saving = true);
    try {
      await api.updateModifierGroup(editing!.id, {
        'name': editName,
        'required': editRequired,
      });
      widget.onRefresh();
      setState(() { editing = null; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally { setState(() => saving = false); }
  }

  Future<void> deleteGroup(int id) async {
    setState(() => saving = true);
    try {
      await api.deleteModifierGroup(id);
      widget.onRefresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally { setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier Groups'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (creating) ...[
              TextField(
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (v) => newName = v,
              ),
              Row(
                children: [
                  Checkbox(value: newRequired, onChanged: (v) => setState(() => newRequired = v ?? false)),
                  const Text('Required'),
                ],
              ),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => creating = false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: saving ? null : createGroup, child: saving ? const CircularProgressIndicator() : const Text('Create')),
                ],
              ),
            ] else if (editing != null) ...[
              TextField(
                decoration: const InputDecoration(labelText: 'Name'),
                controller: TextEditingController(text: editName),
                onChanged: (v) => editName = v,
              ),
              Row(
                children: [
                  Checkbox(value: editRequired, onChanged: (v) => setState(() => editRequired = v ?? false)),
                  const Text('Required'),
                ],
              ),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => editing = null), child: const Text('Cancel')),
                  ElevatedButton(onPressed: saving ? null : saveEdit, child: saving ? const CircularProgressIndicator() : const Text('Save')),
                ],
              ),
            ] else ...[
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.modifierGroups.length,
                  itemBuilder: (context, idx) {
                    final mg = widget.modifierGroups[idx];
                    return ListTile(
                      title: Text(mg.name),
                      subtitle: Text(mg.required ? 'Required' : 'Optional'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () {
                            setState(() {
                              editing = mg;
                              editName = mg.name;
                              editRequired = mg.required;
                            });
                          }),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: saving ? null : () => deleteGroup(mg.id)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => setState(() => creating = true),
                icon: const Icon(Icons.add),
                label: const Text('Add Modifier Group'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

class MenuItemCreateDialog extends StatefulWidget {
  final List<ModifierGroup> modifierGroups;
  final int restaurantId;
  final ApiService api;
  final VoidCallback onSave;
  const MenuItemCreateDialog({required this.modifierGroups, required this.restaurantId, required this.api, required this.onSave, super.key});
  @override
  State<MenuItemCreateDialog> createState() => _MenuItemCreateDialogState();
}

class _MenuItemCreateDialogState extends State<MenuItemCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String description = '';
  String imageUrl = '';
  double price = 0.0;
  bool breakfast = true;
  bool lunch = true;
  bool dinner = true;
  List<int> selectedModifierGroups = [];
  bool saving = false;

  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.api.createMenuItem(
        restaurantId: widget.restaurantId,
        data: {
          'name': name,
          'description': description,
          'price': price,
          'image_url': imageUrl,
          'available_breakfast': breakfast,
          'available_lunch': lunch,
          'available_dinner': dinner,
          'modifier_groups': selectedModifierGroups,
        },
      );
      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Menu Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onChanged: (v) => name = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                onChanged: (v) => description = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Image URL'),
                onChanged: (v) => imageUrl = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final val = double.tryParse(v);
                  if (val == null) return 'Invalid number';
                  if (val < 0) return 'Must be >= 0';
                  return null;
                },
                onChanged: (v) => price = double.tryParse(v) ?? 0.0,
              ),
              Row(
                children: [
                  Checkbox(value: breakfast, onChanged: (v) => setState(() => breakfast = v ?? false)),
                  const Text('Breakfast'),
                  Checkbox(value: lunch, onChanged: (v) => setState(() => lunch = v ?? false)),
                  const Text('Lunch'),
                  Checkbox(value: dinner, onChanged: (v) => setState(() => dinner = v ?? false)),
                  const Text('Dinner'),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Modifier Groups'),
              ...widget.modifierGroups.map((mg) => CheckboxListTile(
                    value: selectedModifierGroups.contains(mg.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          selectedModifierGroups.add(mg.id);
                        } else {
                          selectedModifierGroups.remove(mg.id);
                        }
                      });
                    },
                    title: Text(mg.name),
                    controlAffinity: ListTileControlAffinity.leading,
                  )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: saving ? null : save,
          child: saving ? const CircularProgressIndicator() : const Text('Create'),
        ),
      ],
    );
  }
}