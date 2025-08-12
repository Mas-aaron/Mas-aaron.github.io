from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from api.models import Cart
from api.notifications import send_push_notification

class Command(BaseCommand):
    help = 'Finds carts that have been abandoned and sends a reminder notification to the user.'

    def handle(self, *args, **options):
        # Define what we consider an "abandoned" cart (e.g., updated more than 2 hours ago)
        abandonment_threshold = timezone.now() - timedelta(hours=2)

        self.stdout.write(f'Checking for carts abandoned before {abandonment_threshold.strftime("%Y-%m-%d %H:%M:%S")}...')

        # Find carts that have items and have not been updated recently
        # We also only select carts that have not been recently notified
        abandoned_carts = Cart.objects.filter(
            items__isnull=False,  # Ensure the cart is not empty
            updated_at__lt=abandonment_threshold,
            notified_at__isnull=True # Optional: ensure we don't spam users
        ).distinct()

        if not abandoned_carts.exists():
            self.stdout.write(self.style.SUCCESS('No abandoned carts to notify.'))
            return

        self.stdout.write(f'Found {abandoned_carts.count()} abandoned carts. Sending notifications...')

        notified_count = 0
        for cart in abandoned_carts:
            user = cart.user
            if user and user.devices.filter(is_active=True).exists():
                self.stdout.write(f'  - Sending notification to {user.username} for cart {cart.id}')
                
                success = send_push_notification(
                    user,
                    title="You left something in your cart!",
                    body="Your delicious items are waiting for you. Complete your order now!",
                    data={'cartId': str(cart.id), 'type': 'abandoned_cart'}
                )

                if success:
                    # Mark the cart as notified to avoid sending multiple reminders
                    cart.notified_at = timezone.now()
                    cart.save(update_fields=['notified_at'])
                    notified_count += 1
                else:
                    self.stdout.write(self.style.WARNING(f'    Failed to send notification to {user.username}.'))
            else:
                self.stdout.write(self.style.NOTICE(f'  - Skipping user {user.username} (no active devices).'))

        self.stdout.write(self.style.SUCCESS(f'Successfully sent {notified_count} reminder notifications.'))
