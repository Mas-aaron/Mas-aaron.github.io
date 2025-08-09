from django.contrib import admin, messages
from django.contrib.auth.models import User
from django import forms
from django.urls import path, reverse
from django.shortcuts import render, redirect
from django.utils.html import format_html

from .models import Restaurant, MenuCategory, MenuItem, RiderProfile, Order, Cart, CartItem, NotificationTemplate
from .notifications import send_push_notification

class MenuCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'restaurant')
    list_filter = ('restaurant',)
    search_fields = ('name',)

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        try:
            restaurant = Restaurant.objects.get(owner=request.user)
            return qs.filter(restaurant=restaurant)
        except Restaurant.DoesNotExist:
            return qs.none()

# Form for selecting a user to send the notification to
class SendTemplateForm(forms.Form):
    user = forms.ModelChoiceField(
        queryset=User.objects.filter(devices__isnull=False).distinct(),
        label="Select User",
        required=True,
        widget=forms.Select(attrs={'class': 'form-control'})
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Only show users who have active devices registered
        self.fields['user'].queryset = User.objects.filter(
            devices__is_active=True
        ).distinct().order_by('username')

@admin.register(NotificationTemplate)
class NotificationTemplateAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'title', 'created_at', 'send_test_action')
    list_filter = ('category',)
    search_fields = ('name', 'title', 'body')
    ordering = ('category', 'name')

    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path(
                '<path:template_id>/send/',
                self.admin_site.admin_view(self.send_template_view),
                name='api_notificationtemplate_send',
            ),
            path(
                'send-bulk/<path:template_id>/',
                self.admin_site.admin_view(self.send_bulk_view),
                name='api_notificationtemplate_send_bulk',
            ),
        ]
        return custom_urls + urls

    def send_test_action(self, obj):
        try:
            return format_html(
                '<a class="button" href="{}">Send Test</a>&nbsp;'
                '<a class="button" href="{}" style="background-color:#417690">Send Bulk</a>',
                reverse('admin:api_notificationtemplate_send', args=[obj.pk]),
                reverse('admin:api_notificationtemplate_send_bulk', args=[obj.pk])
            )
        except NoReverseMatch:
            return "Actions unavailable"
    send_test_action.short_description = 'Actions'
    send_test_action.allow_tags = True

    def send_template_view(self, request, template_id):
        template = self.get_object(request, template_id)
        if not template:
            self.message_user(request, "Template not found", level=messages.ERROR)
            return redirect("admin:api_notificationtemplate_changelist")

        if request.method == 'POST':
            form = SendTemplateForm(request.POST)
            if form.is_valid():
                user = form.cleaned_data['user']
                try:
                    if send_push_notification(
                        user=user,
                        title=template.title,
                        body=template.body,
                        data={'template_id': str(template.id)},
                        image_url=template.image_url
                    ):
                        self.message_user(request, f"Test notification sent to {user.username}", level=messages.SUCCESS)
                    else:
                        self.message_user(request, f"Failed to send notification to {user.username}. No active devices found.", level=messages.WARNING)
                except Exception as e:
                    self.message_user(request, f"An error occurred: {e}", level=messages.ERROR)
                return redirect("admin:api_notificationtemplate_changelist")
        else:
            form = SendTemplateForm()

        context = {
            **self.admin_site.each_context(request),
            'opts': self.model._meta,
            'form': form,
            'template': template,
            'title': f'Send Test: {template.name}',
        }
        return render(request, 'admin/send_template_form.html', context)

    def send_bulk_view(self, request, template_id):
        template = self.get_object(request, template_id)
        if not template:
            self.message_user(request, "Template not found", level=messages.ERROR)
            return redirect("admin:api_notificationtemplate_changelist")

        if request.method == 'POST':
            users = User.objects.filter(devices__is_active=True).distinct()
            success_count = 0
            failure_count = 0

            for user in users:
                try:
                    if send_push_notification(
                        user=user,
                        title=template.title,
                        body=template.body,
                        data={'template_id': str(template.id)},
                        image_url=template.image_url
                    ):
                        success_count += 1
                    else:
                        failure_count += 1
                except Exception:
                    failure_count += 1

            self.message_user(
                request,
                f"Sent to {success_count} users, failed for {failure_count}",
                level=messages.SUCCESS if success_count > 0 else messages.WARNING
            )
            return redirect("admin:api_notificationtemplate_changelist")

        context = {
            **self.admin_site.each_context(request),
            'opts': self.model._meta,
            'template': template,
            'user_count': User.objects.filter(devices__is_active=True).count(),
            'title': f'Bulk Send: {template.name}',
        }
        return render(request, 'admin/bulk_send_confirmation.html', context)

    @admin.action(description='Send to selected users')
    def send_to_selected_users(self, request, queryset):
        if queryset.count() > 1:
            self.message_user(request, "Please select only one template", level=messages.ERROR)
            return
        
        template = queryset.first()
        return redirect(reverse('admin:api_notificationtemplate_send', args=[template.id]))

# Register your models here.
admin.site.register(Restaurant)
admin.site.register(MenuCategory, MenuCategoryAdmin)
admin.site.register(MenuItem)
admin.site.register(RiderProfile)
admin.site.register(Order)
admin.site.register(Cart)
admin.site.register(CartItem)

