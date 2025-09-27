"""
Authentication service layer.

Contains reusable business logic for authentication operations.
"""
import re
import hashlib
from datetime import timedelta
from typing import Optional, Tuple
from django.contrib.auth import get_user_model, authenticate, login
from django.contrib.auth.models import AbstractUser
from django.contrib.sessions.models import Session
from django.db import IntegrityError, transaction
from django.core.cache import cache
from rest_framework_simplejwt.tokens import RefreshToken, UntypedToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from users.models import UserSessionProfile
from .tokens import TokenPair

User = get_user_model()

class ValidationError(Exception):
    """Custom validation error for business logic."""
    pass

class ValidationService:
    """Reusable validation functions for user data."""

    @staticmethod
    def validate_email_format(email: str, raise_error: bool = False) -> bool:
        """
        Validate email format using basic pattern.

        Args:
            email: Email to validate
            raise_error: If True, raise ValidationError instead of returning False

        Returns:
            bool: True if valid format

        Raises:
            ValidationError: If raise_error=True and validation fails
        """
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        is_valid = bool(re.match(pattern, email))

        if not is_valid and raise_error:
            raise ValidationError("Invalid email format")

        return is_valid

    @staticmethod
    def validate_password_strength(password: str, raise_error: bool = False) -> bool:
        """
        Validate password strength requirements.

        Args:
            password: Password to validate
            raise_error: If True, raise ValidationError instead of returning False

        Returns:
            bool: True if valid

        Raises:
            ValidationError: If raise_error=True and validation fails
        """
        errors = []

        if len(password) < 8:
            errors.append("Password must be at least 8 characters")

        patterns = [
            (r'[A-Z]', 'Password must contain at least one uppercase letter'),
            (r'[a-z]', 'Password must contain at least one lowercase letter'),
            (r'[0-9]', 'Password must contain at least one number'),
            (r'[!@#$%^&*(),.?":{}|<>]', 'Password must contain at least one special character')
        ]

        for pattern, message in patterns:
            if not re.search(pattern, password):
                errors.append(message)

        is_valid = len(errors) == 0

        if not is_valid and raise_error:
            raise ValidationError('; '.join(errors))

        return is_valid

    @staticmethod
    def validate_display_name_format(display_name: str, raise_error: bool = False) -> bool:
        """
        Validate display name format.

        Args:
            display_name: Display name to validate
            raise_error: If True, raise ValidationError instead of returning False

        Returns:
            bool: True if valid

        Raises:
            ValidationError: If raise_error=True and validation fails
        """
        if not (2 <= len(display_name) <= 50):
            if raise_error:
                raise ValidationError('Display name must be 2-50 characters')
            return False

        pattern = r'^[a-zA-Z0-9\s\-_]+$'
        if not re.match(pattern, display_name):
            if raise_error:
                raise ValidationError(
                    'Display name can only contain alphanumeric characters, spaces, hyphens, and underscores'
                )
            return False

        return True

    @staticmethod
    def validate(email: str, password: str, display_name: str) -> None:
        """
        Validate all user registration data.

        Args:
            email: Email to validate
            password: Password to validate
            display_name: Display name to validate

        Raises:
            ValidationError: If any validation fails
        """
        ValidationService.validate_email_format(email, raise_error=True)
        ValidationService.validate_password_strength(password, raise_error=True)
        ValidationService.validate_display_name_format(display_name, raise_error=True)


class TokenService:
    """Dedicated service for JWT token operations."""

    @staticmethod
    def generate_token_pair(user: AbstractUser, session_profile_id: str) -> TokenPair:
        """
        Generate JWT token pair for user with session tracking.

        Args:
            user: User instance
            session_profile_id: Session profile ID to embed in tokens

        Returns:
            TokenPair: Access and refresh tokens with profile_session_id
        """
        return TokenPair.generate_for_user(user, session_profile_id)

    @staticmethod
    def extract_profile_session_id_from_request(request) -> Optional[str]:
        """
        Extract profile session ID from JWT token in request headers.

        Args:
            request: Django request object

        Returns:
            Optional[str]: Profile session ID if found and valid, None otherwise
        """
        try:
            # Get Authorization header
            auth_header = request.META.get('HTTP_AUTHORIZATION', '')
            if not auth_header.startswith('Bearer '):
                return None

            # Extract token
            token_string = auth_header.split(' ')[1]

            # Use SimpleJWT's token validation
            token = UntypedToken(token_string)

            # Extract profile_session_id claim
            return token.get('profile_session_id')

        except (InvalidToken, TokenError, IndexError, KeyError):
            # Token is invalid or doesn't contain profile_session_id
            return None

    @staticmethod
    def hash_token(token: str) -> str:
        """
        Hash a token for secure storage.

        Args:
            token: Token string to hash

        Returns:
            str: SHA256 hash of token
        """
        return hashlib.sha256(token.encode()).hexdigest()

    @staticmethod
    def verify_token_and_get_user_data(request) -> Tuple[AbstractUser, UserSessionProfile]:
        """
        Verify token and return user data with mandatory session tracking.

        Args:
            request: Django request object (contains authenticated user and JWT token)

        Returns:
            Tuple[AbstractUser, UserSessionProfile]: User and session profile

        Raises:
            ValidationError: If user is inactive, token has no session, or session is invalid
        """
        # Get user from request (already authenticated by JWT middleware)
        user = request.user
        if not user or not user.is_authenticated:
            raise ValidationError("Authentication required")

        # Check if user is active
        if not user.is_active:
            raise ValidationError("User account is disabled")

        # Extract profile session ID from JWT token - this is now mandatory
        profile_session_id = TokenService.extract_profile_session_id_from_request(request)
        if not profile_session_id:
            raise ValidationError("Token missing session tracking - please login again")

        # Get session profile - this must exist
        try:
            session_profile = UserSessionProfile.objects.get(
                profile_id=profile_session_id,
                user=user,
                is_active=True
            )
        except UserSessionProfile.DoesNotExist:
            raise ValidationError("Session expired or invalid - please login again")

        return user, session_profile

    @staticmethod
    def refresh_access_token(refresh_token: str) -> TokenPair:
        """
        Refresh access token and return new tokens.

        Only generates a new access token, keeps the refresh token unchanged.

        Args:
            refresh_token: Refresh token string

        Returns:
            TokenPair: TokenPair with new access token and same refresh token

        Raises:
            ValidationError: If refresh token is invalid/expired
        """
        try:
            # Validate refresh token
            refresh = RefreshToken(refresh_token)

            # Extract user and session from token
            user_id = refresh.get('user_id')
            profile_session_id = refresh.get('profile_session_id')

            if not profile_session_id:
                raise ValidationError("Token missing session tracking - please login again")

            # Verify session is still active
            UserSessionProfile.objects.get(
                profile_id=profile_session_id,
                user_id=user_id,
                is_active=True
            )

            # Generate only new access token, keep same refresh token
            new_access_token = refresh.access_token
            new_access_token['profile_session_id'] = profile_session_id  # Ensure session ID is in access token

            # Extract expiration times
            from datetime import datetime
            access_token_expires_at = datetime.fromtimestamp(new_access_token['exp'])
            refresh_token_expires_at = datetime.fromtimestamp(refresh['exp'])

            # Create TokenPair with new access token and existing refresh token
            from .tokens import TokenPair, AccessToken, RefreshTokenData
            new_tokens = TokenPair(
                access_token=AccessToken(
                    token=str(new_access_token),
                    expires_at=access_token_expires_at
                ),
                refresh_token=RefreshTokenData(
                    token=refresh_token,  # Keep the same refresh token
                    expires_at=refresh_token_expires_at
                )
            )

            # No need to update session refresh_token_hash since refresh token stays the same

            return new_tokens

        except (InvalidToken, TokenError, UserSessionProfile.DoesNotExist):
            raise ValidationError("Invalid or expired refresh token")


class UserRegistrationService:
    """Business logic for user registration."""

    @staticmethod
    def register_user(email: str, password: str, display_name: str) -> AbstractUser:
        """
        Register a new user with comprehensive validation.

        Args:
            email: User's email
            password: User's password
            display_name: User's display name

        Returns:
            User: Created user instance

        Raises:
            ValidationError: If validation fails or user already exists
        """
        # Normalize email
        email = email.lower().strip()

        # Validate all fields (raises ValidationError if invalid)
        ValidationService.validate(email, password, display_name)

        # Check if user already exists
        if User.objects.email_exists(email):
            raise ValidationError('User with this email already exists')

        # Create user using model manager
        try:
            user = User.objects.create_user_account(email, password, display_name)
            return user
        except IntegrityError:
            raise ValidationError('User with this email already exists')


class RateLimitService:
    """Service for handling rate limiting."""

    @staticmethod
    def get_login_attempt_key(ip_address: str) -> str:
        """Generate cache key for login attempts."""
        return f"login_attempts:{ip_address}"

    @staticmethod
    def is_rate_limited(ip_address: str) -> bool:
        """
        Check if IP address is rate limited for login attempts.

        Args:
            ip_address: Client IP address

        Returns:
            bool: True if rate limited, False otherwise
        """
        key = RateLimitService.get_login_attempt_key(ip_address)
        attempts = cache.get(key, 0)
        return attempts >= 5

    @staticmethod
    def increment_login_attempts(ip_address: str) -> int:
        """
        Increment failed login attempts for IP address.

        Args:
            ip_address: Client IP address

        Returns:
            int: Current number of attempts
        """
        key = RateLimitService.get_login_attempt_key(ip_address)
        attempts = cache.get(key, 0) + 1
        cache.set(key, attempts, 900)  # 15 minutes
        return attempts

    @staticmethod
    def reset_login_attempts(ip_address: str) -> None:
        """
        Reset failed login attempts for IP address.

        Args:
            ip_address: Client IP address
        """
        key = RateLimitService.get_login_attempt_key(ip_address)
        cache.delete(key)

class SessionService:
    """Service for managing user sessions using Django sessions + UserSessionProfile."""

    @staticmethod
    @transaction.atomic
    def create_session_with_profile(
        request,
        user: AbstractUser,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None
    ) -> Tuple[UserSessionProfile, TokenPair]:
        """
        Create a new user session using Django sessions + UserSessionProfile with linked JWT tokens.

        Args:
            request: Django request object
            user: User instance
            ip_address: Client IP address
            user_agent: Client user agent

        Returns:
            Tuple[UserSessionProfile, TokenPair]: Created session profile and linked tokens
        """
        # Invalidate existing active sessions for single concurrent session
        SessionService.invalidate_user_sessions(user)

        # Create Django session by logging in the user
        login(request, user)

        # Set session expiry to 30 days
        request.session.set_expiry(timedelta(days=30))

        # Get the created Django session
        django_session = Session.objects.get(session_key=request.session.session_key)

        # Create UserSessionProfile linked to Django session (without tokens first)
        session_profile = UserSessionProfile.objects.create(
            user=user,
            session=django_session,
            refresh_token_hash="",  # Will be updated after token generation
            ip_address=ip_address,
            user_agent=user_agent
        )

        # Generate tokens with session profile ID included
        tokens = TokenService.generate_token_pair(user, str(session_profile.profile_id))

        # Update session profile with actual refresh token hash
        session_profile.refresh_token_hash = TokenService.hash_token(tokens.refresh_token.token)
        session_profile.save(update_fields=['refresh_token_hash'])

        return session_profile, tokens

    @staticmethod
    def get_active_user_sessions(user: AbstractUser) -> list:
        """
        Get all active sessions for a user.

        Args:
            user: User instance

        Returns:
            list: List of active UserSessionProfile objects
        """
        return list(UserSessionProfile.objects.filter(user=user, is_active=True))

    @staticmethod
    def invalidate_user_sessions(user: AbstractUser) -> None:
        """
        Invalidate all sessions for a user.

        Args:
            user: User instance
        """
        # Get all session profiles for the user
        session_profiles = UserSessionProfile.objects.filter(user=user, is_active=True)

        # Invalidate each session profile (this will also delete Django sessions)
        for profile in session_profiles:
            profile.invalidate()

    @staticmethod
    def get_session_profile_by_key(session_key: str) -> Optional[UserSessionProfile]:
        """
        Get session profile by Django session key.

        Args:
            session_key: Django session key

        Returns:
            UserSessionProfile or None: Session profile if found
        """
        try:
            django_session = Session.objects.get(session_key=session_key)
            return UserSessionProfile.objects.get(session=django_session, is_active=True)
        except (Session.DoesNotExist, UserSessionProfile.DoesNotExist):
            return None

    @staticmethod
    def update_session_activity(session_key: str) -> bool:
        """
        Update last activity for a session.

        Args:
            session_key: Django session key

        Returns:
            bool: True if updated successfully
        """
        session_profile = SessionService.get_session_profile_by_key(session_key)
        if session_profile:
            session_profile.update_activity()
            return True
        return False


class UserLoginService:
    """Business logic for user login."""

    @staticmethod
    def authenticate_user(email: str, password: str) -> Optional[AbstractUser]:
        """
        Authenticate user with email and password.

        Args:
            email: User's email (normalized)
            password: User's password

        Returns:
            User instance if authenticated, None otherwise
        """
        user = authenticate(username=email, password=password)
        return user

    @staticmethod
    def login_user(
        request,
        email: str,
        password: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None
    ) -> Tuple[AbstractUser, TokenPair, UserSessionProfile]:
        """
        Process user login with comprehensive validation and security measures.

        Args:
            request: Django request object
            email: User's email
            password: User's password
            ip_address: Client IP address
            user_agent: Client user agent

        Returns:
            Tuple[AbstractUser, TokenPair, UserSessionProfile]: User instance, token pair, and session profile

        Raises:
            ValidationError: If validation fails or authentication fails
        """
        # Normalize email
        email = email.lower().strip()

        # Check rate limiting
        if ip_address and RateLimitService.is_rate_limited(ip_address):
            raise ValidationError('Too many failed login attempts. Please try again later.')

        # Validate email format
        ValidationService.validate_email_format(email, raise_error=True)

        # Check password is not empty
        if not password or not password.strip():
            raise ValidationError('Password is required.')

        # Authenticate user
        user = UserLoginService.authenticate_user(email, password)

        if not user:
            # Increment failed attempts
            if ip_address:
                RateLimitService.increment_login_attempts(ip_address)
            raise ValidationError('Invalid email or password.')

        # Check if user is active
        if not user.is_active:
            raise ValidationError('User account is disabled.')

        # Reset failed attempts on successful login
        if ip_address:
            RateLimitService.reset_login_attempts(ip_address)

        # Create session with Django sessions + profile (this now generates tokens too)
        session_profile, tokens = SessionService.create_session_with_profile(
            request=request,
            user=user,
            ip_address=ip_address,
            user_agent=user_agent
        )

        # Update last login
        user.update_last_login()

        return user, tokens, session_profile


class UserLogoutService:
    """Business logic for user logout."""

    @staticmethod
    def logout_user(request, user: AbstractUser) -> None:
        """
        Process user logout with session invalidation.

        Args:
            request: Django request object
            user: User instance (from authentication)

        Raises:
            ValidationError: If logout fails or user is already logged out
        """
        from django.contrib.auth import logout
        from django.db import DatabaseError

        try:
            # Check if user has any active sessions
            active_sessions = SessionService.get_active_user_sessions(user)
            if not active_sessions:
                raise ValidationError("User is already logged out")

            # Invalidate all user sessions
            SessionService.invalidate_user_sessions(user)

            # Log out from Django session
            logout(request)

        except ValidationError:
            # Re-raise ValidationError as is
            raise
        except DatabaseError as e:
            raise ValidationError(f"Database error during logout: {str(e)}")
        except Exception as e:
            raise ValidationError(f"Logout failed: {str(e)}")