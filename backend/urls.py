from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

admin.site.site_header = "FortExpress Admin"
admin.site.site_title = "FortExpress Admin Portal"
admin.site.index_title = "Welcome to FortExpress Administration"

urlpatterns = [
    path('admin/', admin.site.urls),
    path('payments/', include('payments.urls')),
] + static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
