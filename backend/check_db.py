# filter_system_data.py
import json

# Load the fixture
with open('whole_utf8.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Django system models to exclude (these are causing the issues)
exclude_models = [
    'admin.logentry',           # 7 records
    'auth.permission',          # 152 records
    'auth.group',               # 2 records  
    'auth.user',                # 6 records
    'contenttypes.contenttype', # 38 records (main culprit!)
    'sessions.session',         # 1 record
    'authtoken.token',          # 5 records
]

# Filter out system models - KEEP ONLY YOUR APP DATA
filtered_data = [item for item in data if item['model'] not in exclude_models]

# Save filtered fixture
with open('filtered_data.json', 'w', encoding='utf-8') as f:
    json.dump(filtered_data, f, ensure_ascii=False, indent=2)

print(f"Filtered system data created: filtered_data.json")
print(f"Original items: {len(data)}, Filtered items: {len(filtered_data)}")
print(f"Removed {len(data) - len(filtered_data)} system records")

# Show what's left (your actual application data)
remaining_models = {}
for item in filtered_data:
    remaining_models[item['model']] = remaining_models.get(item['model'], 0) + 1

print('\nYour application data that will be loaded:')
for model, count in remaining_models.items():
    print(f'  {model}: {count} records')