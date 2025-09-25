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
            # 'chat': '/api/chat/',
        }
    })

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', api_root, name='api_root'),
    path('api/users/', include('users.urls')),
    path('api/', include('inventory.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
