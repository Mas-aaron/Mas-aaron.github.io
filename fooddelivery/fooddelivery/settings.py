import os
import dj_database_url


# Database Configuration
DATABASE_URL = os.environ.get('DATABASE_URL')

if DATABASE_URL:
    DATABASES = {
        'default': dj_database_url.parse(DATABASE_URL)
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
        }
    }

# Add SSL and connection settings for production
if 'RENDER' in os.environ:
    DATABASES['default']['OPTIONS'] = {
        'sslmode': 'require',
        'connect_timeout': 30,
    }

# Logging configuration for database issues
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
        },
    },
    'loggers': {
        'django.db.backends': {
            'handlers': ['console'],
            'level': 'DEBUG' if DEBUG else 'INFO',
        },
    },
}

# Ensure debug is False in production
DEBUG = 'RENDER' not in os.environ

# Add render.com to allowed hosts
ALLOWED_HOSTS = [
    'food-delivery-backend-2mcb.onrender.com',
    'localhost',
    '127.0.0.1',
]


INSTALLED_APPS = [
    # ...existing apps...
    
]