from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.apps import apps

class Command(BaseCommand):
    help = 'Seeds the database with initial data'

    def handle(self, *args, **kwargs):
        self.stdout.write('Seeding database...')

        # Use Django's app registry to get models to avoid import issues
        Restaurant = apps.get_model('api', 'Restaurant')
        MenuCategory = apps.get_model('api', 'MenuCategory')

        # Check if data already exists
        if Restaurant.objects.exists():
            self.stdout.write('Database already seeded. Exiting.')
            return

        # Create a user for the restaurants
        user, created = User.objects.get_or_create(
            username='restaurant_owner',
            defaults={'first_name': 'Restaurant', 'last_name': 'Owner'}
        )
        if created:
            user.set_password('defaultpassword')
            user.save()
            self.stdout.write(self.style.SUCCESS('Created default user "restaurant_owner"'))

        # Create Restaurants and Menus
        restaurants_to_create = [
            {'name': 'Cafe Kampala', 'address': '123 Kampala Road', 'dishes': ['Coffee', 'Croissant', 'Samosa']},
            {'name': 'Jinja Grill', 'address': '456 Jinja Avenue', 'dishes': ['Grilled Tilapia', 'Rolex', 'Chips']},
            {'name': 'Entebbe Eats', 'address': '789 Entebbe Street', 'dishes': ['Pizza', 'Burger', 'Milkshake']}
        ]

        for r_data in restaurants_to_create:
            restaurant = Restaurant.objects.create(
                owner=user,
                name=r_data['name'],
                address=r_data['address']
            )
            self.stdout.write(self.style.SUCCESS(f'Created Restaurant: {restaurant.name}'))

            menu = MenuCategory.objects.create(restaurant=restaurant, name=f"{r_data['name']} Menu")
            for dish__name in r_data['dishes']:
                # This part is a placeholder for creating Dish objects.
                # You can adapt this if you have a Dish model.
                pass
            self.stdout.write(self.style.SUCCESS(f'Created Menu for {restaurant.name}'))

        self.stdout.write(self.style.SUCCESS('Database seeding complete.'))
