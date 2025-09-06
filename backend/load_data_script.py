#!/usr/bin/env python
import os
import django
import sys

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

from django.core.management import call_command

def main():
    print("Loading production data...")
    try:
        # Load the data from local_data.json
        call_command('loaddata', 'local_data.json', verbosity=2)
        print("✅ Data loaded successfully!")
    except Exception as e:
        print(f"❌ Error loading data: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
