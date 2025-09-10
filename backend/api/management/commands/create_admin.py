from django.core.management.base import BaseCommand
from django.contrib.auth.models import User, Group
from api.models import Restaurant, MenuCategory, MenuItem
from decimal import Decimal

class Command(BaseCommand):
    help = 'Create admin user and sample data for production'

    def handle(self, *args, **options):
        # Create superuser
        if not User.objects.filter(username='admin').exists():
            admin_user = User.objects.create_superuser(
                username='admin',
                email='admin@fooddelivery.com',
                password='admin123'
            )
            self.stdout.write(
                self.style.SUCCESS('Superuser "admin" created successfully!')
            )
        else:
            admin_user = User.objects.get(username='admin')
            self.stdout.write(
                self.style.WARNING('Superuser "admin" already exists')
            )

        # Create groups
        restaurant_group, created = Group.objects.get_or_create(name='Restaurant')
        if created:
            self.stdout.write(self.style.SUCCESS('Restaurant group created'))

        # Create sample restaurant user
        if not User.objects.filter(username='restaurant_owner').exists():
            restaurant_user = User.objects.create_user(
                username='restaurant_owner',
                email='owner@restaurant.com',
                password='restaurant123',
                first_name='Restaurant',
                last_name='Owner'
            )
            restaurant_user.groups.add(restaurant_group)
            self.stdout.write(self.style.SUCCESS('Restaurant owner user created'))
        else:
            restaurant_user = User.objects.get(username='restaurant_owner')

        # Create sample restaurant
        if not Restaurant.objects.filter(name='Sample Restaurant').exists():
            restaurant = Restaurant.objects.create(
                name='Sample Restaurant',
                description='A sample restaurant for testing',
                address='123 Main Street, City',
                phone='+1234567890',
                email='info@samplerestaurant.com',
                latitude=40.7128,
                longitude=-74.0060,
                owner=restaurant_user,
                is_active=True,
                is_approved=True
            )
            self.stdout.write(self.style.SUCCESS('Sample restaurant created'))

            # Create sample menu category
            category = MenuCategory.objects.create(
                name='Main Dishes',
                description='Our delicious main courses',
                restaurant=restaurant
            )

            # Create sample menu items
            MenuItem.objects.create(
                name='Grilled Chicken',
                description='Juicy grilled chicken with herbs',
                price=Decimal('15.99'),
                category=category,
                is_available=True
            )

            MenuItem.objects.create(
                name='Beef Burger',
                description='Classic beef burger with fries',
                price=Decimal('12.99'),
                category=category,
                is_available=True
            )

            self.stdout.write(self.style.SUCCESS('Sample menu items created'))
        else:
            self.stdout.write(self.style.WARNING('Sample restaurant already exists'))

        self.stdout.write(
            self.style.SUCCESS('Production setup complete!')
        )
