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
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'core',
    'payments',  # Add payments app
]

# Firebase Configuration
FIREBASE_CONFIG = {
    'type': 'service_account',
    'credential_path': os.path.join(BASE_DIR, 'serviceAccountKey.json'),
}

# Supabase Configuration
SUPABASE_URL = os.environ.get('SUPABASE_URL')
SUPABASE_KEY = os.environ.get('SUPABASE_KEY')

# Pesapal Settings
PESAPAL_CONSUMER_KEY = os.environ.get('PESAPAL_CONSUMER_KEY', 'WladF7f2VLuIhN/kjFw9vdpLJy7rWUeH')
PESAPAL_CONSUMER_SECRET = os.environ.get('PESAPAL_CONSUMER_SECRET', 'EcZCXnJcGskMCTrqJyBojVhyUec=')
PESAPAL_BASE_URL = 'https://cybqa.pesapal.com/pesapalv3'  # Sandbox URL
PESAPAL_CALLBACK_URL = 'https://food-delivery-backend-2mcb.onrender.com/payments/callback/'
PESAPAL_IPN_URL = 'https://food-delivery-backend-2mcb.onrender.com/payments/ipn/'

# Django Superuser Configuration
DJANGO_SUPERUSER_USERNAME = os.environ.get('DJANGO_SUPERUSER_USERNAME', 'fortexpress_admin')
DJANGO_SUPERUSER_EMAIL = os.environ.get('DJANGO_SUPERUSER_EMAIL', 'fortexpress@gmail.com')
DJANGO_SUPERUSER_PASSWORD = os.environ.get('DJANGO_SUPERUSER_PASSWORD', 'FortExpress@2024!')

# Admin Configuration
ADMIN_SITE_HEADER = "FortExpress Admin"
ADMIN_SITE_TITLE = "FortExpress Admin Portal"
ADMIN_INDEX_TITLE = "Welcome to FortExpress Administration"

# Templates Configuration
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [
            os.path.join(BASE_DIR, 'templates'),
            os.path.join(BASE_DIR, 'templates', 'admin'),
        ],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# Admin Login/Logout URLs
LOGIN_REDIRECT_URL = 'admin:index'
LOGOUT_REDIRECT_URL = 'admin:login'