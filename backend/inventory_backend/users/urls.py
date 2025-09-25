from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse

def api_root(request):
    return JsonResponse({
        'message': 'Inventory Management API',
        'version': '1.0.0',
        'status': 'active',
        'endpoints': {
            'admin': '/admin/',
            'api_test': '/api/',
            'inventory': '/api/inventory/',
            'users': '/api/users/',
            'chat': '/api/chat/',
        }
    })

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', api_root, name='api_root'),
    path('api/users/', include('users.urls')),  # Add users authentication
    # We'll add these back gradually once the apps are properly set up
    # path('api/inventory/', include('inventory.urls')),
    # path('api/chat/', include('chat.urls')),
]

# Serve media files during development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# backend/users/urls.py

from django.urls import path
from . import views

urlpatterns = [
    path('test/', views.test_view, name='users_test'),
    path('register/', views.register_view, name='register'),
    path('login/', views.login_view, name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('profile/', views.profile_view, name='profile'),
]