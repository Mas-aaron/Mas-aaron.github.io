from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from rest_framework.authtoken.models import Token
from urllib.parse import parse_qs
from .models import Restaurant

@database_sync_to_async
def get_user_with_profile(token_key):
    try:
        token = Token.objects.select_related('user').get(key=token_key)
        user = token.user
        try:
            user.restaurant_profile = Restaurant.objects.filter(owner=user).first()
        except Restaurant.DoesNotExist:
            user.restaurant_profile = None
        return user
    except Token.DoesNotExist:
        return AnonymousUser()

class TokenAuthMiddleware:
    """
    Custom token authentication middleware for Django Channels.
    """

    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        query_string = scope.get('query_string', b'').decode('utf-8')
        query_params = parse_qs(query_string)
        token_key = query_params.get('token', [None])[0]

        if token_key:
            scope['user'] = await get_user_with_profile(token_key)
        else:
            scope['user'] = AnonymousUser()
        
        return await self.inner(scope, receive, send)
