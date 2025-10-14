import os
import dj_database_url

# Pesapal Settings
PESAPAL_CONSUMER_KEY = 'WladF7f2VLuIhN/kjFw9vdpLJy7rWUeH'
PESAPAL_CONSUMER_SECRET = 'EcZCXnJcGskMCTrqJyBojVhyUec='
PESAPAL_BASE_URL = 'https://cybqa.pesapal.com/pesapalv3'  # Sandbox URL
PESAPAL_CALLBACK_URL = 'https://food-delivery-backend-2mcb.onrender.com/payments/callback/'
PESAPAL_IPN_URL = 'https://food-delivery-backend-2mcb.onrender.com/payments/ipn/'

# Database Configuration
DATABASE_URL = os.environ.get('DATABASE_URL', 'postgres://fortexpressdb_user:QrV1v3qr4IjuikDojNXe9trnUZXw6WPL@dpg-d3n8ndod13ps73fuck0g-a.oregon-postgres.render.com/fortexpressdb')

if DATABASE_URL:
    DATABASES = {
        'default': dj_database_url.parse(
            DATABASE_URL,
            conn_max_age=600,
            conn_health_checks=True,
        )
    }
    
    # Enhanced PostgreSQL configuration
    if DATABASES['default']['ENGINE'] == 'django.db.backends.postgresql':
        DATABASES['default'].update({
            'HOST': 'dpg-d3n8ndod13ps73fuck0g-a.oregon-postgres.render.com',
            'PORT': '5432',
            'NAME': 'fortexpressdb',
            'USER': 'fortexpressdb_user',
            'OPTIONS': {
                'sslmode': 'require',
                'keepalives': 1,
                'keepalives_idle': 30,
                'keepalives_interval': 10,
                'keepalives_count': 5,
                'connect_timeout': 30,
            }
        })
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
        }
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