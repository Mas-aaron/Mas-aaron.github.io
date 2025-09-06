from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.db import transaction
from api.models import *
from loyalty.models import *

class Command(BaseCommand):
    help = 'Seed production database with sample data'

    def handle(self, *args, **options):
        with transaction.atomic():
            self.stdout.write('Starting production data seeding...')
            
            # Create sample users
            self.create_users()
            
            # Create sample restaurants
            self.create_restaurants()
            
            # Create sample menu items
            self.create_menu_items()
            
            # Create sample orders
            self.create_orders()
            
            self.stdout.write(self.style.SUCCESS('✅ Production database seeded successfully!'))

    def create_users(self):
        # Create customer users
        if not User.objects.filter(username='customer1').exists():
            user = User.objects.create_user(
                username='customer1',
                email='customer1@example.com',
                password='password123',
                first_name='John',
                last_name='Doe'
            )
            Cart.objects.get_or_create(user=user)
            self.stdout.write('Created customer1')

        if not User.objects.filter(username='customer2').exists():
            user = User.objects.create_user(
                username='customer2',
                email='customer2@example.com',
                password='password123',
                first_name='Jane',
                last_name='Smith'
            )
            Cart.objects.get_or_create(user=user)
            self.stdout.write('Created customer2')

    def create_restaurants(self):
        # Create sample restaurants
        if not Restaurant.objects.filter(name='Pizza Palace').exists():
            restaurant = Restaurant.objects.create(
                name='Pizza Palace',
                description='Authentic Italian pizzas made with fresh ingredients',
                address='123 Main St, Downtown',
                phone='+1234567890',
                email='info@pizzapalace.com',
                is_active=True,
                delivery_fee=2.99,
                minimum_order=15.00,
                estimated_delivery_time=30
            )
            self.stdout.write('Created Pizza Palace restaurant')

        if not Restaurant.objects.filter(name='Burger Barn').exists():
            restaurant = Restaurant.objects.create(
                name='Burger Barn',
                description='Gourmet burgers and crispy fries',
                address='456 Oak Ave, Midtown',
                phone='+1234567891',
                email='info@burgerbarn.com',
                is_active=True,
                delivery_fee=1.99,
                minimum_order=12.00,
                estimated_delivery_time=25
            )
            self.stdout.write('Created Burger Barn restaurant')

    def create_menu_items(self):
        # Create menu items for Pizza Palace
        pizza_palace = Restaurant.objects.filter(name='Pizza Palace').first()
        if pizza_palace and not MenuItem.objects.filter(restaurant=pizza_palace).exists():
            MenuItem.objects.create(
                restaurant=pizza_palace,
                name='Margherita Pizza',
                description='Fresh tomatoes, mozzarella, and basil',
                price=14.99,
                category='Pizza',
                is_available=True
            )
            MenuItem.objects.create(
                restaurant=pizza_palace,
                name='Pepperoni Pizza',
                description='Classic pepperoni with mozzarella cheese',
                price=16.99,
                category='Pizza',
                is_available=True
            )
            self.stdout.write('Created menu items for Pizza Palace')

        # Create menu items for Burger Barn
        burger_barn = Restaurant.objects.filter(name='Burger Barn').first()
        if burger_barn and not MenuItem.objects.filter(restaurant=burger_barn).exists():
            MenuItem.objects.create(
                restaurant=burger_barn,
                name='Classic Burger',
                description='Beef patty with lettuce, tomato, and onion',
                price=12.99,
                category='Burger',
                is_available=True
            )
            MenuItem.objects.create(
                restaurant=burger_barn,
                name='Cheese Fries',
                description='Crispy fries topped with melted cheese',
                price=6.99,
                category='Sides',
                is_available=True
            )
            self.stdout.write('Created menu items for Burger Barn')

    def create_orders(self):
        # Create sample orders
        customer1 = User.objects.filter(username='customer1').first()
        pizza_palace = Restaurant.objects.filter(name='Pizza Palace').first()
        
        if customer1 and pizza_palace and not Order.objects.filter(user=customer1).exists():
            order = Order.objects.create(
                user=customer1,
                restaurant=pizza_palace,
                total_amount=16.99,
                delivery_address='789 Pine St, Apt 2B',
                phone_number='+1234567892',
                status='delivered',
                payment_method='card'
            )
            
            # Add order items
            margherita = MenuItem.objects.filter(restaurant=pizza_palace, name='Margherita Pizza').first()
            if margherita:
                OrderItem.objects.create(
                    order=order,
                    menu_item=margherita,
                    quantity=1,
                    price=margherita.price
                )
            
            self.stdout.write('Created sample order')
