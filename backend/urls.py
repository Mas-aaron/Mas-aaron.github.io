from django.contrib import admin
from django.urls import path, include

# Customize admin site
admin.site.site_header = "FortExpress Admin"
admin.site.site_title = "FortExpress Admin Portal"
admin.site.index_title = "Welcome to FortExpress Administration"

urlpatterns = [
    path('admin/', admin.site.urls),
    path('payments/', include('payments.urls')),  # Include payment URLs
    # ...existing urls...
]
