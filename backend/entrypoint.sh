#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Apply database migrations
echo "Applying database migrations..."
python manage.py migrate

# Collect static files for production
echo "Collecting static files..."
python manage.py collectstatic --noinput

# Create a superuser if it doesn't exist
echo "Checking for superuser..."
python manage.py shell <<EOF
from django.contrib.auth import get_user_model
import os

User = get_user_model()

username = os.environ.get('DJANGO_SUPERUSER_USERNAME', 'admin')
email = os.environ.get('DJANGO_SUPERUSER_EMAIL', 'admin@example.com')
password = os.environ.get('DJANGO_SUPERUSER_PASSWORD')

if not User.objects.filter(username=username).exists():
    if password:
        print(f'Creating superuser {username}')
        User.objects.create_superuser(username, email, password)
    else:
        print('DJANGO_SUPERUSER_PASSWORD not set, skipping superuser creation.')
else:
    print(f'Superuser {username} already exists.')
EOF

# Seed production data if it hasn't been seeded yet
if [ ! -f ".data_seeded" ]; then
    echo "Seeding production data..."
    python manage.py seed_production
    if [ $? -eq 0 ]; then
        touch .data_seeded
        echo "Data seeding completed successfully"
    else
        echo "Data seeding failed, continuing without data"
    fi
fi

# Start the application server
echo "Starting server on port $PORT..."
echo "Using daphne ASGI server..."
exec daphne -b 0.0.0.0 -p $PORT food_delivery.asgi:application
