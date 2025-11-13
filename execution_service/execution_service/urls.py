"""
URL configuration for execution_service project.
"""
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView, SpectacularSwaggerView


def health_check(request):
    """Health check endpoint for ALB"""
    return JsonResponse({"status": "healthy"}, status=200)


class ProxyAwareSwaggerView(SpectacularSwaggerView):
    """
    Custom Swagger view that respects X-Forwarded-Prefix from nginx proxy.
    """
    def get(self, request, *args, **kwargs):
        forwarded_prefix = request.META.get('HTTP_X_FORWARDED_PREFIX', '')
        if forwarded_prefix:
            schema_path = f"{forwarded_prefix}/api/schema/"
            self.url = schema_path
        return super().get(request, *args, **kwargs)


urlpatterns = [
    path("health", health_check, name="health"),
    path('admin/', admin.site.urls),
    path('api/', include('execution_service.apps.urls')),
    
    # OpenAPI 3.0 schema and documentation
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', ProxyAwareSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
]


