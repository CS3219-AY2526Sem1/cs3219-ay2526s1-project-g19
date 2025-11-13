from django.contrib.auth import get_user_model
from typing import Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from django.contrib.auth.models import AbstractUser

User = get_user_model()

def get_user_by_email(email: str) -> Optional['AbstractUser']:
    """Get user by email (case-insensitive)"""
    try:
        return User.objects.get(email__iexact=email)
    except User.DoesNotExist:
        return None

def get_user_by_id(user_id: str) -> Optional['AbstractUser']:
    """Get user by ID"""
    try:
        return User.objects.get(id=user_id)
    except User.DoesNotExist:
        return None