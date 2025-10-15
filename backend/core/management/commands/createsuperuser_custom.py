from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.conf import settings

class Command(BaseCommand):
    help = 'Creates or updates custom superuser with environment variables'

    def handle(self, *args, **options):
        User = get_user_model()
        username = settings.DJANGO_SUPERUSER_USERNAME
        email = settings.DJANGO_SUPERUSER_EMAIL
        password = settings.DJANGO_SUPERUSER_PASSWORD

        # Skip if trying to create 'admin' user that already exists
        if username == 'admin' and User.objects.filter(username='admin').exists():
            self.stdout.write(self.style.WARNING('Default admin user already exists, skipping...'))
            return

        # Create or update our custom superuser
        try:
            user = User.objects.get(username=username)
            user.email = email
            user.set_password(password)
            user.save()
            self.stdout.write(self.style.SUCCESS(f'Custom superuser {username} updated successfully'))
        except User.DoesNotExist:
            User.objects.create_superuser(
                username=username,
                email=email,
                password=password
            )
            self.stdout.write(self.style.SUCCESS(f'Custom superuser {username} created successfully'))
