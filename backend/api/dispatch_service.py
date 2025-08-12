from math import radians, sin, cos, sqrt, atan2
from .models import RiderProfile, Order

def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Calculate the distance between two points in kilometers using the Haversine formula.
    """
    R = 6371  # Radius of Earth in kilometers

    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)

    a = sin(dlat / 2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    distance = R * c
    return distance

def find_and_assign_rider(order):
    """
    Find the nearest available rider and assign them to the given order.
    """
    restaurant = order.restaurant
    if not restaurant.latitude or not restaurant.longitude:
        # Cannot dispatch if the restaurant's location is unknown
        return

    available_riders = RiderProfile.objects.filter(
        is_available=True, 
        latitude__isnull=False, 
        longitude__isnull=False
    )

    if not available_riders.exists():
        # No riders are available, leave the order for manual pickup
        order.status = 'Ready for Pickup'
        order.save()
        return

    nearest_rider = None
    min_distance = float('inf')

    for profile in available_riders:
        distance = calculate_distance(
            restaurant.latitude, restaurant.longitude,
            profile.latitude, profile.longitude
        )
        if distance < min_distance:
            min_distance = distance
            nearest_rider = profile

    if nearest_rider:
        order.rider = nearest_rider.user
        order.status = 'Rider Assigned'
        order.save()
        # TODO: Send a notification to the rider
