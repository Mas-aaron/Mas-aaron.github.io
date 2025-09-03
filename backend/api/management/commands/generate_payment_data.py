from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta, datetime
from decimal import Decimal
from api.models import Order, PaymentPeriod, OrderPayment, Restaurant
import random


class Command(BaseCommand):
    help = 'Generate payment periods and order payment data for restaurants'

    def add_arguments(self, parser):
        parser.add_argument(
            '--restaurant-id',
            type=int,
            help='Generate data for specific restaurant ID',
        )
        parser.add_argument(
            '--weeks',
            type=int,
            default=4,
            help='Number of weeks to generate data for (default: 4)',
        )

    def handle(self, *args, **options):
        restaurant_id = options.get('restaurant_id')
        weeks = options.get('weeks')
        
        if restaurant_id:
            try:
                restaurants = [Restaurant.objects.get(id=restaurant_id)]
            except Restaurant.DoesNotExist:
                self.stdout.write(
                    self.style.ERROR(f'Restaurant with ID {restaurant_id} not found')
                )
                return
        else:
            restaurants = Restaurant.objects.all()

        for restaurant in restaurants:
            self.generate_payment_data(restaurant, weeks)
            self.stdout.write(
                self.style.SUCCESS(
                    f'Generated payment data for {restaurant.name}'
                )
            )

    def generate_payment_data(self, restaurant, weeks):
        now = timezone.now()
        
        for week_offset in range(weeks):
            # Calculate week boundaries
            start_date = now - timedelta(weeks=week_offset, days=now.weekday())
            start_date = start_date.replace(hour=0, minute=0, second=0, microsecond=0)
            end_date = start_date + timedelta(days=7)
            
            # Create or get payment period
            payment_period, created = PaymentPeriod.objects.get_or_create(
                restaurant=restaurant,
                period_type='weekly',
                start_date=start_date,
                end_date=end_date,
                defaults={
                    'status': 'paid' if week_offset > 0 else 'pending',
                    'total_orders': 0,
                    'gross_revenue': Decimal('0.00'),
                    'platform_fee': Decimal('0.00'),
                    'delivery_fee': Decimal('0.00'),
                    'tax_amount': Decimal('0.00'),
                    'adjustments': Decimal('0.00'),
                    'net_payout': Decimal('0.00'),
                }
            )
            
            if created:
                # Get orders for this period
                orders = Order.objects.filter(
                    restaurant=restaurant,
                    created_at__range=[start_date, end_date],
                    status__in=['Delivered', 'Completed']
                )
                
                total_orders = orders.count()
                gross_revenue = Decimal('0.00')
                total_platform_fee = Decimal('0.00')
                total_delivery_fee = Decimal('0.00')
                total_tax = Decimal('0.00')
                
                # Generate order payment details
                for order in orders:
                    subtotal = order.total_price
                    delivery_fee = Decimal(str(random.uniform(2.0, 5.0)))  # Random delivery fee
                    platform_commission = subtotal * Decimal('0.15')  # 15% platform fee
                    service_fee = subtotal * Decimal('0.05')  # 5% service fee
                    tax_amount = subtotal * Decimal('0.08')  # 8% tax
                    tip_amount = Decimal(str(random.uniform(0.0, 3.0)))  # Random tip
                    
                    net_payout = subtotal - platform_commission - service_fee + tip_amount
                    
                    # Create order payment record
                    OrderPayment.objects.get_or_create(
                        order=order,
                        payment_period=payment_period,
                        defaults={
                            'order_number': f'ORD-{order.id:06d}',
                            'order_date': order.created_at,
                            'customer_name': order.user.get_full_name() or order.user.username,
                            'subtotal': subtotal,
                            'delivery_fee': delivery_fee,
                            'service_fee': service_fee,
                            'platform_commission': platform_commission,
                            'tax_amount': tax_amount,
                            'tip_amount': tip_amount,
                            'adjustments': Decimal('0.00'),
                            'net_payout': net_payout,
                            'payment_status': 'paid' if week_offset > 0 else 'pending',
                        }
                    )
                    
                    # Accumulate totals
                    gross_revenue += subtotal
                    total_platform_fee += platform_commission
                    total_delivery_fee += delivery_fee
                    total_tax += tax_amount
                
                # Update payment period totals
                payment_period.total_orders = total_orders
                payment_period.gross_revenue = gross_revenue
                payment_period.platform_fee = total_platform_fee
                payment_period.delivery_fee = total_delivery_fee
                payment_period.tax_amount = total_tax
                payment_period.net_payout = gross_revenue - total_platform_fee
                payment_period.save()
