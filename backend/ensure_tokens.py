#!/usr/bin/env python3
"""Ensures every user has a valid authentication token."""

import os
import django

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

from django.contrib.auth.models import User
from rest_framework.authtoken.models import Token

def ensure_all_user_tokens():
    """Creates a token for any user that does not have one."""
    print("--- Ensuring all users have an auth token ---")
    users_without_tokens = User.objects.filter(auth_token__isnull=True)
    
    if not users_without_tokens.exists():
        print("All users already have tokens. No action needed.")
        return

    print(f"Found {users_without_tokens.count()} users without tokens. Generating now...")
    for user in users_without_tokens:
        token, created = Token.objects.get_or_create(user=user)
        if created:
            print(f"  - Created token for: {user.username}")
    print("-------------------------------------------")

if __name__ == '__main__':
    ensure_all_user_tokens()
