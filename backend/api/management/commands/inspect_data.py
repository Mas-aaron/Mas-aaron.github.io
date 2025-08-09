from django.core.management.base import BaseCommand
from api.models import Order, Restaurant

class Command(BaseCommand):
    help = 'Inspects the relationship between Orders and Restaurants.'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('--- Inspecting Restaurant Data ---'))
        restaurants = Restaurant.objects.all()
        if not restaurants.exists():
            self.stdout.write(self.style.WARNING('No restaurants found in the database.'))
        else:
            for r in restaurants:
                self.stdout.write(f'  [OK] Restaurant ID: {r.id}, Name: {r.name}')

        self.stdout.write(self.style.SUCCESS('\n--- Inspecting Order Data ---'))
        orders = Order.objects.all()
        if not orders.exists():
            self.stdout.write(self.style.WARNING('No orders found in the database.'))
            return

        valid_restaurant_ids = set(Restaurant.objects.values_list('id', flat=True))
        all_orders_valid = True

        for order in orders:
            try:
                # This access will fail if the FK is broken at the DB level
                restaurant_name = order.restaurant.name
                if order.restaurant_id not in valid_restaurant_ids:
                    self.stdout.write(self.style.ERROR(
                        f'  [INVALID] Order ID: {order.id} -> Restaurant ID: {order.restaurant_id} (Name: {restaurant_name}) - FK exists in Django but not in DB list.'))
                    all_orders_valid = False
                else:
                    self.stdout.write(f'  [OK] Order ID: {order.id} -> Restaurant ID: {order.restaurant_id} (Name: {restaurant_name})')
            except Restaurant.DoesNotExist:
                self.stdout.write(self.style.ERROR(
                    f'  [ORPHAN] Order ID: {order.id} -> Restaurant ID: {order.restaurant_id} - The referenced restaurant does not exist!'))
                all_orders_valid = False
        
        if all_orders_valid:
            self.stdout.write(self.style.SUCCESS('\nAll order-restaurant relationships appear to be valid.'))
