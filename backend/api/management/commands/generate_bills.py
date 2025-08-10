from django.core.management.base import BaseCommand
from django.db import transaction
from django.db.models import Sum
from api.models import Restaurant, Order, Bill

class Command(BaseCommand):
    help = 'Generates bills for restaurants based on completed, unbilled orders.'

    def handle(self, *args, **options):
        self.stdout.write('Starting bill generation process...')

        restaurants = Restaurant.objects.all()
        bill_count = 0

        for restaurant in restaurants:
            with transaction.atomic():
                orders_to_bill = Order.objects.filter(
                    restaurant=restaurant,
                    status='Completed',
                    is_billed=False
                )

                if not orders_to_bill.exists():
                    continue

                total_amount = orders_to_bill.aggregate(total=Sum('total_price'))['total']

                if total_amount is None or total_amount <= 0:
                    continue

                # Create a new bill
                new_bill = Bill.objects.create(
                    restaurant=restaurant,
                    amount=total_amount,
                    status='pending'
                )

                # Mark orders as billed
                orders_to_bill.update(is_billed=True)

                bill_count += 1
                self.stdout.write(self.style.SUCCESS(
                    f'Successfully created Bill #{new_bill.id} for {restaurant.name} for an amount of ${total_amount:.2f}'
                ))

        self.stdout.write(self.style.SUCCESS(f'Bill generation complete. Created {bill_count} new bills.'))
