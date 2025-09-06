#!/usr/bin/env python
import os
import json
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

from django.core import serializers
from api.models import *
from loyalty.models import *
from django.contrib.auth.models import User

def export_data():
    data = []
    
    # Export users (excluding superusers to avoid conflicts)
    users = User.objects.filter(is_superuser=False)
    for user in users:
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
                "date_joined": user.date_joined.isoformat() if user.date_joined else None,
                "last_login": user.last_login.isoformat() if user.last_login else None,
            }
        })
    
    # Export restaurants
    for restaurant in Restaurant.objects.all():
        data.append({
            "model": "api.restaurant",
            "pk": restaurant.pk,
            "fields": {
                "name": restaurant.name,
                "address": restaurant.address,
                "phone_number": restaurant.phone_number,
                "email": restaurant.email,
                "is_approved": restaurant.is_approved,
                "order_protocol": restaurant.order_protocol,
                "latitude": str(restaurant.latitude) if restaurant.latitude else None,
                "longitude": str(restaurant.longitude) if restaurant.longitude else None,
            }
        })
    
    # Export menu categories
    for category in MenuCategory.objects.all():
        data.append({
            "model": "api.menucategory",
            "pk": category.pk,
            "fields": {
                "restaurant": category.restaurant.pk,
                "name": category.name,
            }
        })
    
    # Export menu items
    for item in MenuItem.objects.all():
        data.append({
            "model": "api.menuitem",
            "pk": item.pk,
            "fields": {
                "category": item.category.pk,
                "name": item.name,
                "description": item.description,
                "price": str(item.price),
                "available_breakfast": item.available_breakfast,
                "available_lunch": item.available_lunch,
                "available_dinner": item.available_dinner,
            }
        })
    
    # Export carts
    for cart in Cart.objects.all():
        data.append({
            "model": "api.cart",
            "pk": cart.pk,
            "fields": {
                "user": cart.user.pk,
            }
        })
    
    # Write to file with UTF-8 encoding
    with open('final_production_data.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"Exported {len(data)} objects successfully")

if __name__ == "__main__":
    export_data()
