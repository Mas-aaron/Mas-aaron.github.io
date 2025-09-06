from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.db import transaction
from api.models import Restaurant, MenuCategory, MenuItem, Cart
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
                address='123 Main St, Downtown',
                phone_number='+1234567890',
                email='info@pizzapalace.com',
                is_approved=True,
                order_protocol='TABLET'
            )
            self.stdout.write('Created Pizza Palace restaurant')

        if not Restaurant.objects.filter(name='Burger Barn').exists():
            restaurant = Restaurant.objects.create(
                name='Burger Barn',
                address='456 Oak Ave, Midtown',
                phone_number='+1234567891',
                email='info@burgerbarn.com',
                is_approved=True,
                order_protocol='TABLET'
            )
            self.stdout.write('Created Burger Barn restaurant')

    def create_menu_items(self):
        # Create menu categories and items for Pizza Palace
        pizza_palace = Restaurant.objects.filter(name='Pizza Palace').first()
        if pizza_palace and not MenuCategory.objects.filter(restaurant=pizza_palace).exists():
            pizza_category = MenuCategory.objects.create(
                restaurant=pizza_palace,
                name='Pizza'
            )
            MenuItem.objects.create(
                category=pizza_category,
                name='Margherita Pizza',
                description='Fresh tomatoes, mozzarella, and basil',
                price=14.99
            )
            MenuItem.objects.create(
                category=pizza_category,
                name='Pepperoni Pizza',
                description='Classic pepperoni with mozzarella cheese',
                price=16.99
            )
            self.stdout.write('Created menu items for Pizza Palace')

        # Create menu categories and items for Burger Barn
        burger_barn = Restaurant.objects.filter(name='Burger Barn').first()
        if burger_barn and not MenuCategory.objects.filter(restaurant=burger_barn).exists():
            burger_category = MenuCategory.objects.create(
                restaurant=burger_barn,
                name='Burgers'
            )
            sides_category = MenuCategory.objects.create(
                restaurant=burger_barn,
                name='Sides'
            )
            MenuItem.objects.create(
                category=burger_category,
                name='Classic Burger',
                description='Beef patty with lettuce, tomato, and onion',
                price=12.99
            )
            MenuItem.objects.create(
                category=sides_category,
                name='Cheese Fries',
                description='Crispy fries topped with melted cheese',
                price=6.99
            )
            self.stdout.write('Created menu items for Burger Barn')

    def create_orders(self):
        # Skip order creation for now to avoid model complexity
        self.stdout.write('Skipping order creation - restaurants and menu items created successfully')
