from rest_framework.permissions import BasePermission, SAFE_METHODS
from .models import Restaurant, Order

class IsCustomer(BasePermission):
    """
    Custom permission to only allow customers (non-restaurant owners) to access an endpoint.
    """
    message = 'Only customer accounts can access this endpoint.'

    def has_permission(self, request, view):
        # Check if the user is authenticated first
        if not request.user or not request.user.is_authenticated:
            return False
        # Check if the user is associated with a restaurant profile.
        # If they are, they are a restaurant owner, not a customer.
        return not Restaurant.objects.filter(owner=request.user).exists()

class IsRestaurantOwner(BasePermission):
    """Permission to only allow restaurant owners to access an endpoint."""
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and hasattr(request.user, 'restaurant_profile')

class IsOwnerOfOrder(BasePermission):
    """Permission to only allow the owner of an order to view or edit it."""
    def has_object_permission(self, request, view, obj):
        # For Order objects, check if the user is the customer or the restaurant owner.
        if isinstance(obj, Order):
            is_customer = obj.user == request.user
            is_restaurant_owner = hasattr(request.user, 'restaurant_profile') and obj.restaurant == request.user.restaurant_profile
            return is_customer or is_restaurant_owner
        return False
