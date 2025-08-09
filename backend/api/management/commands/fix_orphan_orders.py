from django.core.management.base import BaseCommand
from django.db import transaction
from api.models import Order, Restaurant

class Command(BaseCommand):
    help = 'Finds and re-assigns orders pointing to non-existent restaurants.'

    def handle(self, *args, **options):
        self.stdout.write('Starting orphan order check...')

        # Get all restaurant IDs that actually exist
        valid_restaurant_ids = set(Restaurant.objects.values_list('id', flat=True))
        self.stdout.write(f'Found {len(valid_restaurant_ids)} valid restaurants.')

        # Find all orders
        orders = Order.objects.all()
        orphan_orders = []

        for order in orders:
            if order.restaurant_id not in valid_restaurant_ids:
                orphan_orders.append(order)

        if not orphan_orders:
            self.stdout.write(self.style.SUCCESS('No orphan orders found. Database is clean.'))
            return

        self.stdout.write(self.style.WARNING(f'Found {len(orphan_orders)} orphan orders.'))

        # Get the first valid restaurant to assign orphans to
        fallback_restaurant = Restaurant.objects.first()
        if not fallback_restaurant:
            self.stdout.write(self.style.ERROR('No valid restaurants found to assign orphans to. Aborting.'))
            return

        self.stdout.write(f'Using restaurant "{fallback_restaurant.name}" (ID: {fallback_restaurant.id}) as the fallback.' )

        updated_count = 0
        with transaction.atomic():
            for order in orphan_orders:
                old_restaurant_id = order.restaurant_id
                order.restaurant = fallback_restaurant
                order.save()
                updated_count += 1
                self.stdout.write(f'  - Re-assigned Order ID {order.id} from invalid Restaurant ID {old_restaurant_id} to {fallback_restaurant.id}')

        self.stdout.write(self.style.SUCCESS(f'Successfully re-assigned {updated_count} orphan orders.'))
