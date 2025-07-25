from django.contrib import admin
from .models import Restaurant, MenuCategory, MenuItem, RiderProfile, Order, Cart, CartItem

# Register your models here.
admin.site.register(Restaurant)
admin.site.register(MenuCategory)
admin.site.register(MenuItem)
admin.site.register(RiderProfile)
admin.site.register(Order)
admin.site.register(Cart)
admin.site.register(CartItem)

