from django.db import models
from api.models import Order

class Payment(models.Model):
    PAYMENT_STATUS = (
        ('PENDING', 'Pending'),
        ('COMPLETED', 'Completed'),
        ('FAILED', 'Failed'),
        ('CANCELLED', 'Cancelled'),
    )

    CURRENCY_CHOICES = (
        ('UGX', 'Ugandan Shilling'),
        ('KES', 'Kenyan Shilling'),
        ('USD', 'US Dollar'),
    )

    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='pesapal_payment', null=True, blank=True)
    order_tracking_id = models.CharField(max_length=100, unique=True)
    merchant_reference = models.CharField(max_length=100, unique=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=3, choices=CURRENCY_CHOICES, default='UGX')
    status = models.CharField(max_length=20, choices=PAYMENT_STATUS, default='PENDING')
    
    # Customer details
    customer_email = models.EmailField(null=True, blank=True)
    customer_phone = models.CharField(max_length=20, null=True, blank=True)
    customer_name = models.CharField(max_length=100, null=True, blank=True)
    
    # Pesapal specific fields
    pesapal_transaction_id = models.CharField(max_length=100, null=True, blank=True)
    payment_method = models.CharField(max_length=50, null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.merchant_reference} - {self.amount} {self.currency}"

    class Meta:
        ordering = ['-created_at']
