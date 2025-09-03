from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from api.models import Restaurant, CustomerProfile, User
from api.notifications import send_push_notification
import logging
import math

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = 'Notify users about new restaurants in their area'

    def add_arguments(self, parser):
        parser.add_argument(
            '--hours',
            type=int,
            default=24,
            help='Check for restaurants added in the last N hours (default: 24)'
        )
        parser.add_argument(
            '--radius',
            type=float,
            default=5.0,
            help='Radius in kilometers to search for nearby users (default: 5.0)'
        )

    def handle(self, *args, **options):
        hours = options['hours']
        radius_km = options['radius']
        
        # Find restaurants created in the last N hours
        time_threshold = timezone.now() - timedelta(hours=hours)
        new_restaurants = Restaurant.objects.filter(
            created_at__gte=time_threshold,
            is_approved=True
        )

        if not new_restaurants.exists():
            self.stdout.write(self.style.SUCCESS(f'No new restaurants found in the last {hours} hours.'))
            return

        self.stdout.write(f'Found {new_restaurants.count()} new restaurants. Checking for nearby users...')

        total_notifications = 0
        
        for restaurant in new_restaurants:
            if not restaurant.latitude or not restaurant.longitude:
                self.stdout.write(self.style.WARNING(f'Skipping {restaurant.name} - no location data'))
                continue

            # Find users within radius who have location data
            nearby_users = User.objects.filter(
                customerprofile__latitude__isnull=False,
                customerprofile__longitude__isnull=False,
                devices__is_active=True
            ).distinct()

            restaurant_notifications = 0
            
            for user in nearby_users:
                try:
                    profile = user.customerprofile
                    
                    # Calculate distance using Haversine formula
                    distance_km = self.calculate_distance(
                        restaurant.latitude, restaurant.longitude,
                        profile.latitude, profile.longitude
                    )
                    
                    if distance_km <= radius_km:
                        # Send notification
                        success = send_push_notification(
                            user,
                            title="🍽️ New Restaurant in Your Area!",
                            body=f"{restaurant.name} just joined our platform near you. Check out their menu!",
                            data={
                                'type': 'new_restaurant',
                                'restaurant_id': str(restaurant.id),
                                'restaurant_name': restaurant.name,
                                'distance_km': round(distance_km, 1)
                            }
                        )
                        
                        if success:
                            restaurant_notifications += 1
                            self.stdout.write(f'  ✓ Notified {user.username} about {restaurant.name} ({distance_km:.1f}km away)')
                        else:
                            self.stdout.write(self.style.WARNING(f'  ✗ Failed to notify {user.username}'))
                            
                except Exception as e:
                    logger.error(f'Error processing user {user.id}: {str(e)}')
                    continue
            
            total_notifications += restaurant_notifications
            self.stdout.write(f'Sent {restaurant_notifications} notifications for {restaurant.name}')

        self.stdout.write(self.style.SUCCESS(f'Successfully sent {total_notifications} new restaurant notifications.'))

    def calculate_distance(self, lat1, lon1, lat2, lon2):
        """
        Calculate the great circle distance between two points 
        on the earth (specified in decimal degrees) using Haversine formula
        Returns distance in kilometers
        """
        # Convert decimal degrees to radians
        lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])

        # Haversine formula
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        
        # Radius of earth in kilometers
        r = 6371
        
        return c * r
