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

# Test Django configuration
echo "Testing Django configuration..."
python -c "
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
import django
django.setup()
from django.core.wsgi import get_wsgi_application
app = get_wsgi_application()
print('Django WSGI application loaded successfully')
"

# Start the application server
echo "Starting server on port $PORT..."
echo "About to start gunicorn..."
exec gunicorn food_delivery.wsgi:application --bind 0.0.0.0:$PORT --workers 1 --timeout 120 --log-level info
