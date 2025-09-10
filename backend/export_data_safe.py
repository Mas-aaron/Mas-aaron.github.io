#!/usr/bin/env python
"""
Safe data export script that handles Unicode characters properly
"""
import os
import django
import json
import sys

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

from django.core import serializers
from django.contrib.auth.models import User, Group
from api.models import *

def safe_export():
    """Export data with proper Unicode handling"""
    
    # Set UTF-8 encoding for output
    if sys.platform == 'win32':
        import codecs
        sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer)
    
    # Export specific models in order
    models_to_export = [
        'auth.group',
        'auth.user', 
        'api.restaurant',
        'api.menucategory',
        'api.menuitem',
        'api.customerprofile',
    ]
    
    data = []
    
    try:
        # Export Groups
        for group in Group.objects.all():
            data.append({
                "model": "auth.group",
                "pk": group.pk,
                "fields": {"name": group.name}
            })
        
        # Export Users (excluding sensitive data)
        for user in User.objects.all():
            data.append({
                "model": "auth.user", 
                "pk": user.pk,
                "fields": {
                    "username": user.username,
                    "first_name": user.first_name,
                    "last_name": user.last_name,
                    "email": user.email,
                    "is_staff": user.is_staff,
                    "is_active": user.is_active,
                    "is_superuser": user.is_superuser,
                    "date_joined": user.date_joined.isoformat(),
                    "password": user.password,  # Keep encrypted password
                    "groups": list(user.groups.values_list('pk', flat=True)),
                }
            })
        
        # Export Restaurants
        for restaurant in Restaurant.objects.all():
            data.append({
                "model": "api.restaurant",
                "pk": restaurant.pk, 
                "fields": {
                    "name": restaurant.name,
                    "description": restaurant.description or "",
                    "address": restaurant.address or "",
                    "phone": restaurant.phone or "",
                    "email": restaurant.email or "",
                    "latitude": float(restaurant.latitude) if restaurant.latitude else None,
                    "longitude": float(restaurant.longitude) if restaurant.longitude else None,
                    "is_active": restaurant.is_active,
                    "is_approved": getattr(restaurant, 'is_approved', True),
                    "owner": restaurant.owner.pk if restaurant.owner else None,
                    "created_at": restaurant.created_at.isoformat(),
                    "updated_at": restaurant.updated_at.isoformat(),
                }
            })
        
        # Export Menu Categories
        for category in MenuCategory.objects.all():
            data.append({
                "model": "api.menucategory",
                "pk": category.pk,
                "fields": {
                    "name": category.name,
                    "description": category.description or "",
                    "restaurant": category.restaurant.pk,
                    "created_at": category.created_at.isoformat(),
                    "updated_at": category.updated_at.isoformat(),
                }
            })
        
        # Export Menu Items
        for item in MenuItem.objects.all():
            data.append({
                "model": "api.menuitem",
                "pk": item.pk,
                "fields": {
                    "name": item.name,
                    "description": item.description or "",
                    "price": str(item.price),
                    "category": item.category.pk,
                    "is_available": item.is_available,
                    "created_at": item.created_at.isoformat(),
                    "updated_at": item.updated_at.isoformat(),
                }
            })
        
        # Save to file with UTF-8 encoding
        with open('production_data.json', 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        
        print(f"✅ Successfully exported {len(data)} records to production_data.json")
        print("📁 File saved with UTF-8 encoding")
        
    except Exception as e:
        print(f"❌ Error during export: {e}")
        return False
    
    return True

if __name__ == '__main__':
    success = safe_export()
    if success:
        print("\n🚀 Ready to deploy to production!")
    else:
        print("\n💥 Export failed - check errors above")
