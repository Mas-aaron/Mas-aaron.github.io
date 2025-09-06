#!/usr/bin/env python
import os
import django
import sys

def main():
    print("Loading production data...")
    try:
        # Setup Django with proper environment
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
        
        # Import Django after environment setup
        import django
        from django.conf import settings
        
        # Configure Django
        django.setup()
        
        # Import management command after Django setup
        from django.core.management import call_command
        
        # Verify database connection before loading
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        
        print("Database connection verified, loading data...")
        
        # Load the data from local_data.json
        call_command('loaddata', 'local_data.json', verbosity=1)
        print("✅ Data loaded successfully!")
        
    except Exception as e:
        print(f"❌ Error loading data: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
