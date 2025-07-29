#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Apply database migrations
echo "Applying database migrations..."
python manage.py migrate

# Seed the database with initial data
# We will run this every time, but our seed script should be smart enough
# not to create duplicate data.
echo "Seeding database..."
python manage.py seed

# Start the application server
echo "Starting server..."
exec daphne -b 0.0.0.0 -p "$PORT" food_delivery.asgi:application
