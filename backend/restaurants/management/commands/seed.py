from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from restaurants.models import Restaurant, Menu

class Command(BaseCommand):
    help = 'Seeds the database with initial data'

    def handle(self, *args, **kwargs):
        self.stdout.write('Seeding database...')

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

            menu = Menu.objects.create(restaurant=restaurant, name=f"{r_data['name']} Menu")
            for dish_name in r_data['dishes']:
                # Assuming you have a 'Dish' model with a 'menu' foreign key and 'name' and 'price' fields
                # This part is commented out as I don't know your exact Dish model structure
                # You can uncomment and adapt it if you have a Dish model.
                # from restaurants.models import Dish
                # Dish.objects.create(menu=menu, name=dish_name, price=10.00) # Example price
                pass
            self.stdout.write(self.style.SUCCESS(f'Created Menu for {restaurant.name}'))

        self.stdout.write(self.style.SUCCESS('Database seeding complete.'))
