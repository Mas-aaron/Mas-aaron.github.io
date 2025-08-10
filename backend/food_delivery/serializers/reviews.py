from rest_framework import serializers
from ..models.reviews import OrderReview, RiderReview
from ..models.order import Order

class OrderReviewSerializer(serializers.ModelSerializer):
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())

    class Meta:
        model = OrderReview
        fields = ['id', 'order', 'user', 'rating', 'comment', 'created_at']
        read_only_fields = ['id', 'created_at']

    def validate_order(self, value):
        """
        Check that the order is delivered and belongs to the user.
        """
        if value.user != self.context['request'].user:
            raise serializers.ValidationError("You can only review your own orders.")
        if value.status.lower() != 'delivered':
            raise serializers.ValidationError("You can only review delivered orders.")
        if OrderReview.objects.filter(order=value).exists():
            raise serializers.ValidationError("This order has already been reviewed.")
        return value

class RiderReviewSerializer(serializers.ModelSerializer):
    user = serializers.HiddenField(default=serializers.CurrentUserDefault())

    class Meta:
        model = RiderReview
        fields = ['id', 'order', 'user', 'rating', 'comment', 'created_at']
        read_only_fields = ['id', 'created_at']

    def validate_order(self, value):
        """
        Check that the order is delivered, belongs to the user, and has a rider.
        """
        if value.user != self.context['request'].user:
            raise serializers.ValidationError("You can only review riders for your own orders.")
        if value.status.lower() != 'delivered':
            raise serializers.ValidationError("You can only review riders for delivered orders.")
        if not hasattr(value, 'rider') or value.rider is None:
             raise serializers.ValidationError("This order does not have a rider to review.")
        if RiderReview.objects.filter(order=value).exists():
            raise serializers.ValidationError("The rider for this order has already been reviewed.")
        return value
