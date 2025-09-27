"""
Authentication app URL configuration.

Handles all authentication-related endpoints including:
- User registration
- Login/logout (future)
- Password reset (future)
- Email verification (future)
"""
from django.urls import path
from .views import UserRegistrationView, UserLoginView, UserLogoutView, TokenVerifyView, RefreshTokenView

app_name = 'authentication'

urlpatterns = [
    path('register/', UserRegistrationView.as_view(), name='register'),
    path('login/', UserLoginView.as_view(), name='login'),
    path('logout/', UserLogoutView.as_view(), name='logout'),
    path('verify-token/', TokenVerifyView.as_view(), name='verify-token'),
    path('refresh/', RefreshTokenView.as_view(), name='refresh'),
    # Future endpoints:
    # path('forgot-password/', ForgotPasswordView.as_view(), name='forgot-password'),
    # path('reset-password/', ResetPasswordView.as_view(), name='reset-password'),
    # path('verify-email/', VerifyEmailView.as_view(), name='verify-email'),
    # path('resend-verification/', ResendVerificationView.as_view(), name='resend-verification'),
]