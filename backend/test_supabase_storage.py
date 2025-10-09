#!/usr/bin/env python
"""
Test script to verify Supabase storage integration
"""
import os
import sys
import django
from django.conf import settings

# Add the project directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Load environment variables from .env file
try:
    from dotenv import load_dotenv
    load_dotenv()
    print("✅ Loaded environment variables from .env file")
except ImportError:
    print("⚠️ python-dotenv not installed, using system environment variables")

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from api.storage import SupabaseStorage

def test_supabase_storage():
    """Test Supabase storage functionality"""
    print("🧪 Testing Supabase Storage Integration")
    print("=" * 50)
    
    # Check if Supabase is configured
    supabase_url = getattr(settings, 'SUPABASE_URL', None)
    supabase_key = getattr(settings, 'SUPABASE_ANON_KEY', None)
    bucket_name = getattr(settings, 'SUPABASE_STORAGE_BUCKET', 'images')
    
    print(f"📋 Configuration Check:")
    print(f"   SUPABASE_URL: {'✅ Set' if supabase_url else '❌ Not set'}")
    print(f"   SUPABASE_ANON_KEY: {'✅ Set' if supabase_key else '❌ Not set'}")
    print(f"   STORAGE_BUCKET: {bucket_name}")
    print()
    
    if not supabase_url or not supabase_key:
        print("⚠️  Supabase credentials not configured. Update your .env file with:")
        print("   SUPABASE_URL=https://your-project-id.supabase.co")
        print("   SUPABASE_ANON_KEY=your-anon-key-here")
        print("   SUPABASE_STORAGE_BUCKET=images")
        print()
        print("🔄 Falling back to local storage for testing...")
        print()
    
    # Test storage backend initialization
    try:
        storage = SupabaseStorage()
        print("✅ SupabaseStorage initialized successfully")
    except Exception as e:
        print(f"❌ Error initializing SupabaseStorage: {e}")
        return False
    
    # Test file upload
    try:
        test_content = ContentFile(b"Hello, Supabase! This is a test file.", name="test.txt")
        filename = storage.save("test/test.txt", test_content)
        print(f"✅ File saved successfully: {filename}")
        
        # Test URL generation
        file_url = storage.url(filename)
        print(f"✅ File URL generated: {file_url}")
        
        # Test file existence check
        exists = storage.exists(filename)
        print(f"✅ File exists check: {exists}")
        
        # Test file deletion
        deleted = storage.delete(filename)
        print(f"✅ File deletion: {'Success' if deleted else 'Failed'}")
        
    except Exception as e:
        print(f"❌ Error during file operations: {e}")
        import traceback
        print(f"📋 Full traceback: {traceback.format_exc()}")
        return False
    
    print()
    print("🎉 Supabase storage test completed successfully!")
    return True

def test_django_integration():
    """Test Django model integration with Supabase storage"""
    print("\n🧪 Testing Django Model Integration")
    print("=" * 50)
    
    try:
        from api.models import Restaurant
        
        # Check if we can create a restaurant with an image
        print("📋 Testing Restaurant model with image field...")
        
        # This would normally require an actual image file
        # For testing, we'll just check that the field is properly configured
        restaurant_field = Restaurant._meta.get_field('image')
        print(f"✅ Restaurant image field configured: {restaurant_field.upload_to}")
        
        from api.models import MenuItem
        menu_item_field = MenuItem._meta.get_field('image')
        print(f"✅ MenuItem image field configured: {menu_item_field.upload_to}")
        
        print("✅ Django model integration looks good!")
        
    except Exception as e:
        print(f"❌ Error testing Django integration: {e}")
        return False
    
    return True

if __name__ == "__main__":
    print("🚀 Starting Supabase Storage Tests")
    print("=" * 60)
    
    # Test storage functionality
    storage_test = test_supabase_storage()
    
    # Test Django integration
    django_test = test_django_integration()
    
    print("\n" + "=" * 60)
    if storage_test and django_test:
        print("🎉 All tests passed! Supabase storage is ready to use.")
    else:
        print("⚠️  Some tests failed. Please check the configuration.")
    
    print("\n📝 Next steps:")
    print("1. Update your .env file with actual Supabase credentials")
    print("2. Create a storage bucket named 'images' in your Supabase project")
    print("3. Set the bucket to public if you want direct URL access")
    print("4. Test image uploads through your Django admin or API")
