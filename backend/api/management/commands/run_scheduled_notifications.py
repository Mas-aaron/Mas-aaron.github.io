from django.core.management.base import BaseCommand
from django.core.management import call_command
import logging

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = 'Run all scheduled notification tasks (forgotten carts and new restaurants)'

    def handle(self, *args, **options):
        self.stdout.write('Running scheduled notification tasks...')
        
        try:
            # Run forgotten cart notifications
            self.stdout.write('1. Checking for abandoned carts...')
            call_command('send_abandoned_cart_reminders')
            
            # Run new restaurant notifications (last 24 hours)
            self.stdout.write('2. Checking for new restaurants...')
            call_command('notify_new_restaurants', '--hours=24', '--radius=5.0')
            
            self.stdout.write(self.style.SUCCESS('All scheduled notifications completed successfully.'))
            
        except Exception as e:
            logger.error(f'Error running scheduled notifications: {str(e)}')
            self.stdout.write(self.style.ERROR(f'Error: {str(e)}'))
