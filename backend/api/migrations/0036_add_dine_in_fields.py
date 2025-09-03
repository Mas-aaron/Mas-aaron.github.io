# Generated manually for dine-in feature

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0035_orderpayment_paymentperiod_paymentdispute_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='order',
            name='order_type',
            field=models.CharField(
                choices=[('delivery', 'Delivery'), ('pickup', 'Pickup'), ('dine_in', 'Dine In')],
                default='delivery',
                max_length=20
            ),
        ),
        migrations.AddField(
            model_name='order',
            name='scheduled_time',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='order',
            name='estimated_prep_time',
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='order',
            name='table_number',
            field=models.CharField(blank=True, max_length=10, null=True),
        ),
        migrations.AddField(
            model_name='order',
            name='tip_amount',
            field=models.DecimalField(decimal_places=2, default=0.0, max_digits=10),
        ),
        migrations.AlterField(
            model_name='order',
            name='status',
            field=models.CharField(
                choices=[
                    ('pending', 'Pending'),
                    ('confirmed', 'Confirmed'),
                    ('preparing', 'Preparing'),
                    ('ready_for_pickup', 'Ready for Pickup'),
                    ('ready_for_dine_in', 'Ready for Dine-in'),
                    ('out_for_delivery', 'Out for Delivery'),
                    ('rider_arrived', 'Rider Arrived'),
                    ('delivered', 'Delivered'),
                    ('completed', 'Completed'),
                    ('cancelled', 'Cancelled')
                ],
                default='pending',
                max_length=20
            ),
        ),
    ]
