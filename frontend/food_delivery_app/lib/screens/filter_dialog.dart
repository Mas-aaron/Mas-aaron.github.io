import 'package:flutter/material.dart';
import 'package:food_delivery_app/models/dietary_preference.dart';
import 'package:food_delivery_app/services/profile_service.dart';

class FilterDialog extends StatefulWidget {
  final List<int> selectedIds;

  const FilterDialog({super.key, required this.selectedIds});

  @override
  _FilterDialogState createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late Future<List<DietaryPreference>> _futurePreferences;
  late Set<int> _tempSelectedIds;

  @override
  void initState() {
    super.initState();
    _futurePreferences = ProfileService().getDietaryPreferences();
    _tempSelectedIds = Set<int>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter by Dietary Preference'),
      content: FutureBuilder<List<DietaryPreference>>(
        future: _futurePreferences,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text('No preferences available.');
          }

          final preferences = snapshot.data!;
          return SingleChildScrollView(
            child: Wrap(
              spacing: 8.0,
              children: preferences.map((preference) {
                final isSelected = _tempSelectedIds.contains(preference.id);
                return FilterChip(
                  label: Text(preference.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _tempSelectedIds.add(preference.id);
                      } else {
                        _tempSelectedIds.remove(preference.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          child: const Text('Clear'),
          onPressed: () {
            setState(() {
              _tempSelectedIds.clear();
            });
          },
        ),
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('Apply'),
          onPressed: () => Navigator.of(context).pop(_tempSelectedIds.toList()),
        ),
      ],
    );
  }
}
