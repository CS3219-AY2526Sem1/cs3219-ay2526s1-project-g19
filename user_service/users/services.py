"""
Users service layer.

Contains reusable business logic for user operations.
"""
from django.contrib.auth import get_user_model
from uuid import UUID

User = get_user_model()


class ValidationError(Exception):
    """Custom validation error for business logic."""
    pass


class PublicProfileService:
    """Service for handling public user profile operations."""

    @staticmethod
    def get_public_profile(user_id: UUID):
        """
        Retrieve public profile information for a user.

        Args:
            user_id: UUID of the user to fetch

        Returns:
            User: User instance with basic profile information

        Raises:
            ValidationError: If user is not found or account is disabled
        """
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            raise ValidationError("User not found")

        # Check if user account is active
        if not user.is_active:
            raise ValidationError("User account is disabled")

        return user
