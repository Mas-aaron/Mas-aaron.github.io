from rest_framework import permissions
from api.models import Restaurant

class IsRestaurantOwner(permissions.BasePermission):
    """
    Custom permission to only allow owners of a restaurant to access it.
    """

    def has_permission(self, request, view):
        # Check if the user is authenticated and has a restaurant profile.
        if not request.user or not request.user.is_authenticated:
            return False
        
        try:
            # Check if a restaurant profile exists for the user.
            return Restaurant.objects.filter(owner=request.user).exists()
        except Restaurant.DoesNotExist:
            return False
