"""
Email verification URL configuration.

Handles email verification endpoints:
- Send/resend verification email
- Check verification status
"""
from django.urls import path
from .views import send_verification_email, get_verification_status

app_name = 'email_verification'

urlpatterns = [
    path('send/', send_verification_email, name='send-verification'),
    path('status/', get_verification_status, name='verification-status'),
]
