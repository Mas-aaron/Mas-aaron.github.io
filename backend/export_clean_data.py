#!/usr/bin/env python
import os
import django
import json
from django.core import serializers

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

from django.contrib.auth.models import User, Group
from api.models import *

def clean_string(s):
    """Remove problematic Unicode characters"""
    if isinstance(s, str):
        # Replace problematic Unicode characters with safe alternatives
        s = s.encode('ascii', 'ignore').decode('ascii')
        return s
    return s

def export_data():
    data = []
    
    # Export Groups
    for group in Group.objects.all():
        data.append({
            "model": "auth.group",
            "pk": group.pk,
            "fields": {
                "name": clean_string(group.name),
            }
        })
    
    # Export Users
    for user in User.objects.all():
        data.append({
            "model": "auth.user",
            "pk": user.pk,
            "fields": {
                "username": clean_string(user.username),
                "first_name": clean_string(user.first_name),
                "last_name": clean_string(user.last_name),
                "email": clean_string(user.email),
                "password": user.password,
                "is_staff": user.is_staff,
                "is_active": user.is_active,
                "is_superuser": user.is_superuser,
                "date_joined": user.date_joined.isoformat(),
                "last_login": user.last_login.isoformat() if user.last_login else None,
                "groups": list(user.groups.values_list('pk', flat=True)),
            }
        })
    
    # Export Restaurants
    for restaurant in Restaurant.objects.all():
        data.append({
            "model": "api.restaurant",
            "pk": restaurant.pk,
            "fields": {
                "name": clean_string(restaurant.name),
                "description": clean_string(restaurant.description),
                "address": clean_string(restaurant.address),
                "phone": clean_string(restaurant.phone),
                "email": clean_string(restaurant.email),
                "latitude": float(restaurant.latitude) if restaurant.latitude else None,
                "longitude": float(restaurant.longitude) if restaurant.longitude else None,
                "is_active": restaurant.is_active,
                "created_at": restaurant.created_at.isoformat(),
                "updated_at": restaurant.updated_at.isoformat(),
            }
        })
    
    # Export Categories
    for category in Category.objects.all():
        data.append({
            "model": "api.category",
            "pk": category.pk,
            "fields": {
                "name": clean_string(category.name),
                "description": clean_string(category.description),
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
                "name": clean_string(item.name),
                "description": clean_string(item.description),
                "price": str(item.price),
                "category": item.category.pk,
                "is_available": item.is_available,
                "created_at": item.created_at.isoformat(),
                "updated_at": item.updated_at.isoformat(),
            }
        })
    
    # Save to file
    with open('local_data.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=True)
    
    print(f"Exported {len(data)} records to local_data.json")

if __name__ == '__main__':
    export_data()
