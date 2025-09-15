#!/bin/bash
# Exit on error
set -o errexit

# Upgrade pip and force reinstall dependencies
pip install --upgrade pip
pip install --upgrade --force-reinstall -r requirements.txt

# Explicitly install django-storages to ensure it's available
pip install --force-reinstall django-storages[google]==1.14.3

# Convert static asset files
python manage.py collectstatic --noinput

# Apply any outstanding database migrations
python manage.py migrate
