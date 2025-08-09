from django.core.management.base import BaseCommand, CommandError
from django.contrib.auth.models import User, Group

class Command(BaseCommand):
    help = 'Assigns a user to the Rider group, creating the group if it does not exist.'

    def add_arguments(self, parser):
        parser.add_argument('username', type=str, help='The username of the user to add to the Rider group')

    def handle(self, *args, **options):
        username = options['username']
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            raise CommandError(f'User "{username}" does not exist')

        rider_group, created = Group.objects.get_or_create(name='Rider')

        if created:
            self.stdout.write(self.style.SUCCESS('Successfully created "Rider" group.'))

        if rider_group in user.groups.all():
            self.stdout.write(self.style.WARNING(f'User "{username}" is already in the "Rider" group.'))
        else:
            user.groups.add(rider_group)
            self.stdout.write(self.style.SUCCESS(f'Successfully added user "{username}" to the "Rider" group.'))
