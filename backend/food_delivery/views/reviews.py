from rest_framework import viewsets, permissions
from ..permissions import IsRestaurantOwner
from api.models import OrderReview, RiderReview
from api.serializers import OrderReviewSerializer, RiderReviewSerializer

class OrderReviewViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows users to create and view order reviews.
    """
    queryset = OrderReview.objects.all()
    serializer_class = OrderReviewSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """
        This view should return a list of all the reviews
        for the currently authenticated user.
        """
        return self.queryset.filter(user=self.request.user)

class RiderReviewViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows users to create and view rider reviews.
    """
    queryset = RiderReview.objects.all()
    serializer_class = RiderReviewSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """
        This view should return a list of all reviews for the
        currently authenticated rider.
        """
        # The rider is the one being reviewed, so we filter by the rider's user profile.
        # Assumes RiderReview model has a 'rider' foreign key to the RiderProfile model,
        # and RiderProfile has a one-to-one link to the User model.
        try:
            # Ensure the user has a rider profile before querying
            if hasattr(self.request.user, 'rider_profile'):
                rider_profile = self.request.user.rider_profile
                return self.queryset.filter(rider=rider_profile)
        except AttributeError:
            # This case handles anonymous users or users without the rider_profile attribute gracefully.
            pass
        # Return an empty queryset if no valid rider profile is found
        return self.queryset.none()


class RestaurantOrderReviewViewSet(viewsets.ReadOnlyModelViewSet):
    """
    API endpoint that allows restaurants to view their order reviews.
    """
    serializer_class = OrderReviewSerializer
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwner]

    def get_queryset(self):
        """
        This view should return a list of all reviews for the
        currently authenticated restaurant user.
        """
        restaurant = self.request.user.restaurant_profile
        return OrderReview.objects.filter(order__restaurant=restaurant).order_by('-created_at')

