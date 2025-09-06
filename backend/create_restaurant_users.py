#!/usr/bin/env python3
"""Create restaurant users and assign them to restaurants"""

import os
import django
from django.conf import settings

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

from django.contrib.auth.models import User, Group
from api.models import Restaurant
from rest_framework.authtoken.models import Token

def create_restaurant_users():
    print("=== Creating Restaurant Users ===")
    
    # Get or create restaurant group
    restaurant_group, created = Group.objects.get_or_create(name='Restaurant')
    if created:
        print("✓ Created Restaurant group")
    
    # Restaurant data
    restaurant_data = [
        {
            'name': 'Betty Burgers',
            'email': 'bettybinega@yahoo.com',
            'password': 'password123'
        },
        {
            'name': 'The Pizza Palace', 
            'email': 'pizza@palace.com',
            'password': 'password123'
        },
        {
            'name': 'Burger Barn',
            'email': 'burger@barn.com', 
            'password': 'password123'
        },
        {
            'name': 'Taco Town',
            'email': 'taco@town.com',
            'password': 'password123'
        }
    ]
    
    for rest_data in restaurant_data:
        # Create or get user
        user, created = User.objects.get_or_create(
            email=rest_data['email'],
            defaults={
                'username': rest_data['email'],
                'first_name': rest_data['name'].split()[0],
                'last_name': ' '.join(rest_data['name'].split()[1:]) if len(rest_data['name'].split()) > 1 else '',
                'is_active': True
            }
        )
        
        if created:
            user.set_password(rest_data['password'])
            user.save()
            print(f"✓ Created user: {user.email}")
        else:
            print(f"→ User exists: {user.email}")
        
        # Add to restaurant group
        user.groups.add(restaurant_group)
        
        # Create auth token
        token, token_created = Token.objects.get_or_create(user=user)
        if token_created:
            print(f"  → Created token: {token.key[:10]}...")
        
        # Find and assign restaurant
        try:
            # Try exact match first
            restaurant = Restaurant.objects.get(name=rest_data['name'])
        except Restaurant.DoesNotExist:
            # Try partial match
            restaurants = Restaurant.objects.filter(name__icontains=rest_data['name'].split()[0])
            if restaurants.exists():
                restaurant = restaurants.first()
            else:
                # Create restaurant if it doesn't exist
                restaurant = Restaurant.objects.create(
                    name=rest_data['name'],
                    address=f"123 {rest_data['name']} Street",
                    phone="123-456-7890",
                    is_approved=True,
                    latitude=0.0,
                    longitude=0.0
                )
                print(f"  → Created restaurant: {restaurant.name}")
        
        # Assign owner
        restaurant.owner = user
        restaurant.save()
        print(f"  → Assigned {user.email} to {restaurant.name}")
    
    print("\n=== Final Status ===")
    print(f"Users: {User.objects.count()}")
    print(f"Restaurants: {Restaurant.objects.count()}")
    print(f"Tokens: {Token.objects.count()}")
    
    print("\n=== Restaurant Assignments ===")
    for restaurant in Restaurant.objects.all():
        if restaurant.owner:
            token = Token.objects.get(user=restaurant.owner)
            print(f"✓ {restaurant.name}: {restaurant.owner.email} (Token: {token.key})")
        else:
            print(f"✗ {restaurant.name}: No owner")

if __name__ == '__main__':
    create_restaurant_users()
