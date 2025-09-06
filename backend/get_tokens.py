#!/usr/bin/env python3
"""Fetch and print user authentication tokens from the database."""

import os
import django

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

from django.contrib.auth.models import User
from rest_framework.authtoken.models import Token

def fetch_tokens():
    """Fetches and prints all user tokens."""
    print("--- Fetching User Authentication Tokens ---")
    users = User.objects.all()
    if not users.exists():
        print("No users found in the database.")
        return

    for user in users:
        try:
            token = Token.objects.get(user=user)
            print(f"User: {user.username} ({user.email})")
            print(f"  Token: {token.key}")
        except Token.DoesNotExist:
            print(f"User: {user.username} ({user.email})")
            print(f"  Token: NOT FOUND")
    print("-----------------------------------------")

if __name__ == '__main__':
    fetch_tokens()
