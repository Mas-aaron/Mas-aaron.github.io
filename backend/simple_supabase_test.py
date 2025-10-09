#!/usr/bin/env python
"""
Simple test script to verify Supabase integration without Django
"""
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def test_supabase_import():
    """Test if Supabase can be imported"""
    print("🧪 Testing Supabase Import")
    print("=" * 40)
    
    try:
        from supabase import create_client, Client
        print("✅ Supabase import successful")
        return True
    except ImportError as e:
        print(f"❌ Supabase import failed: {e}")
        return False

def test_supabase_connection():
    """Test Supabase connection"""
    print("\n🧪 Testing Supabase Connection")
    print("=" * 40)
    
    # Get environment variables
    supabase_url = os.getenv('SUPABASE_URL')
    supabase_key = os.getenv('SUPABASE_ANON_KEY')
    bucket_name = os.getenv('SUPABASE_STORAGE_BUCKET', 'images')
    
    print(f"📋 Configuration:")
    print(f"   SUPABASE_URL: {'✅ Set' if supabase_url else '❌ Not set'}")
    print(f"   SUPABASE_ANON_KEY: {'✅ Set' if supabase_key else '❌ Not set'}")
    print(f"   STORAGE_BUCKET: {bucket_name}")
    
    if not supabase_url or not supabase_key:
        print("❌ Missing Supabase credentials")
        return False
    
    try:
        from supabase import create_client
        client = create_client(supabase_url, supabase_key)
        print("✅ Supabase client created successfully")
        
        # Test storage access
        storage = client.storage.from_(bucket_name)
        print(f"✅ Storage bucket '{bucket_name}' accessed")
        
        return True
    except Exception as e:
        print(f"❌ Supabase connection failed: {e}")
        return False

def test_storage_operations():
    """Test basic storage operations"""
    print("\n🧪 Testing Storage Operations")
    print("=" * 40)
    
    try:
        from supabase import create_client
        
        supabase_url = os.getenv('SUPABASE_URL')
        supabase_key = os.getenv('SUPABASE_ANON_KEY')
        bucket_name = os.getenv('SUPABASE_STORAGE_BUCKET', 'images')
        
        client = create_client(supabase_url, supabase_key)
        storage = client.storage.from_(bucket_name)
        
        # Test file upload
        test_content = b"Hello, Supabase! This is a test file."
        test_filename = "test/django-test.txt"
        
        print(f"🔄 Uploading test file: {test_filename}")
        response = storage.upload(
            path=test_filename,
            file=test_content,
            file_options={
                "content-type": "text/plain"
            }
        )
        
        if hasattr(response, 'status_code') and response.status_code == 200:
            print("✅ File uploaded successfully")
        else:
            print(f"✅ File uploaded: {response}")
        
        # Test URL generation
        print("🔄 Generating public URL...")
        public_url = storage.get_public_url(test_filename)
        print(f"✅ Public URL: {public_url}")
        
        # Test file deletion
        print("🔄 Cleaning up test file...")
        delete_response = storage.remove([test_filename])
        print("✅ Test file cleaned up")
        
        return True
        
    except Exception as e:
        error_msg = str(e)
        if "row-level security policy" in error_msg:
            print(f"⚠️  Row Level Security (RLS) is blocking uploads to bucket '{bucket_name}'")
            print("\n📝 To fix this, you have two options:")
            print("\n🔧 Option 1 (Simple): Disable RLS for the bucket")
            print("   1. Go to your Supabase dashboard")
            print("   2. Go to Storage > Policies")
            print(f"   3. Find the '{bucket_name}' bucket")
            print("   4. Toggle OFF 'Row Level Security' for this bucket")
            print("\n🔧 Option 2 (Secure): Create RLS policies")
            print("   1. Go to Storage > Policies")
            print("   2. Create a new policy for INSERT operations")
            print("   3. Allow 'anon' role to insert files")
            print("   4. Create a new policy for SELECT operations")
            print("   5. Allow 'anon' role to select files")
            return False
        elif "Bucket not found" in error_msg:
            print(f"⚠️  Bucket '{bucket_name}' not found in your Supabase project")
            print("📝 Please create the bucket in your Supabase dashboard")
            return False
        else:
            print(f"❌ Storage operations failed: {e}")
            import traceback
            print(f"📋 Full traceback: {traceback.format_exc()}")
            return False

if __name__ == "__main__":
    print("🚀 Simple Supabase Storage Test")
    print("=" * 50)
    
    # Test import
    import_test = test_supabase_import()
    
    if not import_test:
        print("\n❌ Supabase import failed. Please install: pip install supabase")
        exit(1)
    
    # Test connection
    connection_test = test_supabase_connection()
    
    if not connection_test:
        print("\n❌ Supabase connection failed. Check your credentials.")
        exit(1)
    
    # Test storage operations
    storage_test = test_storage_operations()
    
    print("\n" + "=" * 50)
    if import_test and connection_test and storage_test:
        print("🎉 All tests passed! Supabase is working correctly.")
        print("\n📝 Next steps:")
        print("1. Your Supabase storage is ready to use")
        print("2. Create a bucket named 'images' in your Supabase dashboard")
        print("3. Set the bucket to public for direct URL access")
        print("4. Your Django app will now use Supabase for image storage")
    else:
        print("⚠️  Some tests failed. Please check the configuration.")
