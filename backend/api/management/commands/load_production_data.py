import os
import json
from django.core.management.base import BaseCommand
from django.core.management import call_command
from django.conf import settings

class Command(BaseCommand):
    help = 'Load data from local_data.json into production database'

    def add_arguments(self, parser):
        parser.add_argument(
            '--file',
            type=str,
            default='local_data.json',
            help='JSON file to load data from'
        )

    def handle(self, *args, **options):
        file_path = options['file']
        
        if not os.path.exists(file_path):
            self.stdout.write(
                self.style.ERROR(f'File {file_path} not found')
            )
            return

        self.stdout.write(f'Loading data from {file_path}...')
        
        try:
            # Load the data
            call_command('loaddata', file_path, verbosity=2)
            self.stdout.write(
                self.style.SUCCESS('Data loaded successfully!')
            )
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error loading data: {e}')
            )
