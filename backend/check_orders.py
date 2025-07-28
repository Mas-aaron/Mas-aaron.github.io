import os
import django
from django.conf import settings

# Set up Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'food_delivery.settings')
django.setup()

# Now we can import and use Django models
from api.models import Order

print('Orders:', Order.objects.count())
orders = Order.objects.all()
for order in orders:
    print(f'Order {order.id}: {order.status}')
