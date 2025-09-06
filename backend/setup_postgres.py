# fix_user_groups.py
import json

# Load the fixture
with open('fixed_final_fixture.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Find and fix the user with group ID 1
fixed_count = 0
for item in data:
    if item['model'] == 'auth.user':
        fields = item.get('fields', {})
        if 'groups' in fields and fields['groups'] == [1]:
            fields['groups'] = []  # Remove the group association
            fixed_count += 1
            print(f"Fixed user {item['pk']}: removed group association [1]")

# Save the fixed fixture
with open('fully_fixed_fixture.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"Fixed {fixed_count} users. Saved as fully_fixed_fixture.json")