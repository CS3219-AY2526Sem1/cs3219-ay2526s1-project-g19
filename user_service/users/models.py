from django.contrib.auth.models import AbstractUser, UserManager
from django.contrib.sessions.models import Session
from django.db import models
from django.core.validators import EmailValidator
from django.utils import timezone
import uuid

class CustomUserManager(UserManager):
    """Custom manager for User model with additional helper methods."""

    def email_exists(self, email: str) -> bool:
        """
        Check if user exists by email (case-insensitive).

        Args:
            email: Email to check

        Returns:
            True if user exists, False otherwise
        """
        return self.filter(email__iexact=email).exists()

    def create_user_account(self, email: str, password: str, display_name: str):
        """
        Create a new user account with normalized data.

        Args:
            email: User's email address (will be normalized)
            password: User's password (will be hashed)
            display_name: User's display name

        Returns:
            User instance

        Raises:
            IntegrityError: If email already exists
        """
        return self.create_user(
            username=email,
            email=email.lower(),
            password=password,
            first_name=display_name,
            is_verified=False
        )

class User(AbstractUser):
    """
    Custom User model extending Django's AbstractUser.

    Adds UUID primary key, email verification status, and timestamps.
    Uses email as the primary authentication field instead of username.
    """
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text="Unique identifier for the user"
    )
    email = models.EmailField(
        unique=True,
        validators=[EmailValidator()],
        help_text="Required. Enter a valid email address."
    )
    phone_number = models.CharField(
        max_length=15,
        blank=True,
        null=True,
        help_text="Optional phone number"
    )
    date_of_birth = models.DateField(
        blank=True,
        null=True,
        help_text="User's date of birth"
    )
    is_verified = models.BooleanField(
        default=False,
        help_text="Whether the user's email has been verified"
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the user account was created"
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        help_text="When the user account was last updated"
    )

    # Use custom manager
    objects = CustomUserManager()

    # Use email as username field
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username', 'first_name', 'last_name']

    class Meta:
        db_table = 'users'
        verbose_name = 'User'
        verbose_name_plural = 'Users'
        indexes = [
            models.Index(fields=['email']),
            models.Index(fields=['is_verified']),
            models.Index(fields=['created_at']),
        ]

    def __str__(self) -> str:
        """String representation of the user."""
        full_name = self.get_full_name()
        return f"{self.email} ({full_name})" if full_name else self.email

    def update_last_login(self) -> None:
        """
        Update the user's last login timestamp.

        This method updates only the last_login field for efficiency.
        """
        self.last_login = timezone.now()
        self.save(update_fields=['last_login'])


class UserSessionProfile(models.Model):
    """
    Extended session profile that works with Django's built-in Session model.

    This model stores additional metadata for user sessions while leveraging
    Django's existing session framework for the core session management.
    """
    profile_id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        help_text="Unique identifier for the session profile"
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='session_profiles',
        help_text="User associated with this session"
    )
    session = models.OneToOneField(
        Session,
        on_delete=models.CASCADE,
        related_name='user_profile',
        help_text="Django session associated with this profile"
    )
    refresh_token_hash = models.CharField(
        max_length=255,
        help_text="Hashed refresh token for JWT"
    )
    ip_address = models.GenericIPAddressField(
        null=True,
        blank=True,
        help_text="IP address of the session"
    )
    user_agent = models.TextField(
        null=True,
        blank=True,
        help_text="User agent string"
    )
    login_at = models.DateTimeField(
        auto_now_add=True,
        help_text="When the user logged in"
    )
    last_activity_at = models.DateTimeField(
        default=timezone.now,
        help_text="Last activity timestamp"
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Whether the session is active"
    )

    class Meta:
        db_table = 'user_session_profiles'
        verbose_name = 'User Session Profile'
        verbose_name_plural = 'User Session Profiles'
        indexes = [
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['login_at']),
            models.Index(fields=['last_activity_at']),
        ]

    def __str__(self) -> str:
        """String representation of the session profile."""
        return f"Session Profile {self.profile_id} for {self.user.email}"

    def is_expired(self) -> bool:
        """Check if the underlying Django session is expired."""
        return self.session.expire_date < timezone.now()

    def invalidate(self) -> None:
        """Invalidate both the session profile and Django session."""
        self.is_active = False
        self.save(update_fields=['is_active'])
        # Also delete the Django session
        self.session.delete()

    def update_activity(self) -> None:
        """Update last activity timestamp."""
        self.last_activity_at = timezone.now()
        self.save(update_fields=['last_activity_at'])
    