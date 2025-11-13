"""
URL configuration for question_service project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
# question_service/question_service/urls.py
from django.urls import path, include
from django.http import JsonResponse
from django.contrib import admin
from rest_framework.routers import DefaultRouter
from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView, SpectacularSwaggerView
from .view import QuestionViewSet, TopicsView, DifficultiesView


def health_check(request):
    """Health check endpoint for ALB"""
    return JsonResponse({"status": "healthy"}, status=200)


class ProxyAwareSwaggerView(SpectacularSwaggerView):
    """
    Custom Swagger view that respects X-Forwarded-Prefix from nginx proxy.
    Generates the correct schema URL when accessed through a proxy path like /question-service-api
    """
    def get(self, request, *args, **kwargs):
        # Get the forwarded prefix from nginx
        forwarded_prefix = request.META.get('HTTP_X_FORWARDED_PREFIX', '')

        # If accessed through proxy, prepend the prefix to the schema URL
        if forwarded_prefix:
            # Get the full schema path with prefix
            schema_path = f"{forwarded_prefix}/api/schema/"
            # Override url to use absolute path
            self.url = schema_path

        return super().get(request, *args, **kwargs)


router = DefaultRouter()
router.register(r"questions", QuestionViewSet, basename="questions")

urlpatterns = [
    path("health", health_check, name="health"),  # Health check for ALB
    # Django Admin
    path('admin/', admin.site.urls),
    
    # API endpoints
    path("api/", include(router.urls)),
    path("api/topics", TopicsView.as_view(), name="topics"),
    path("api/difficulty", DifficultiesView.as_view(), name="difficulties"),

    # OpenAPI 3.0 schema and documentation
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', ProxyAwareSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/', SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
]
