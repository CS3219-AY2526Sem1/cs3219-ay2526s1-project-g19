"""
Authentication serializers.

Thin validation layer for API input/output.
Business logic is handled in services layer.
"""
from rest_framework import serializers
from users.serializers import UserMeSerializer

class UserRegistrationInputSerializer(serializers.Serializer):
    """
    Input serializer for user registration.

    Performs basic field validation only.
    Business logic validation is handled in services.
    """
    email = serializers.EmailField(
        required=True,
        help_text="Valid email address"
    )
    password = serializers.CharField(
        required=True,
        min_length=1,  # Basic validation, detailed in service
        write_only=True,
        help_text="User password"
    )
    display_name = serializers.CharField(
        required=True,
        min_length=1,  # Basic validation, detailed in service
        max_length=100,  # Liberal limit, detailed in service
        help_text="User display name"
    )

class UserRegistrationOutputSerializer(serializers.Serializer):
    """
    Output serializer for user registration response.

    Takes User object and formats it properly.
    """
    user = UserMeSerializer(read_only=True)
    # access_token = serializers.CharField(read_only=True)  # Future JWT token


class UserLoginInputSerializer(serializers.Serializer):
    """
    Input serializer for user login.

    Performs basic field validation only.
    Business logic validation is handled in services.
    """
    email = serializers.EmailField(
        required=True,
        help_text="Valid email address"
    )
    password = serializers.CharField(
        required=True,
        min_length=1,
        write_only=True,
        help_text="User password"
    )

    def validate_email(self, value):
        """Normalize email to lowercase."""
        return value.lower().strip()


class AccessTokenSerializer(serializers.Serializer):
    """
    Serializer for AccessToken dataclass.
    """
    token = serializers.CharField(read_only=True)
    expires_at = serializers.DateTimeField(read_only=True)


class RefreshTokenSerializer(serializers.Serializer):
    """
    Serializer for RefreshTokenData dataclass.
    """
    token = serializers.CharField(read_only=True)
    expires_at = serializers.DateTimeField(read_only=True)


class TokensSerializer(serializers.Serializer):
    """
    Serializer for TokenPair using individual token serializers.

    Clean, modular approach with DRY principle.
    """
    access_token = AccessTokenSerializer(read_only=True)
    refresh_token = RefreshTokenSerializer(read_only=True)


class SessionProfileSerializer(serializers.Serializer):
    """
    Serializer for user session profile information.
    """
    profile_id = serializers.UUIDField(read_only=True)
    session_key = serializers.CharField(source='session.session_key', read_only=True)
    ip_address = serializers.IPAddressField(read_only=True)
    user_agent = serializers.CharField(read_only=True)
    login_at = serializers.DateTimeField(read_only=True)
    last_activity_at = serializers.DateTimeField(read_only=True)
    is_active = serializers.BooleanField(read_only=True)


class UserLoginOutputSerializer(serializers.Serializer):
    """
    Output serializer for user login response.

    Returns user profile data, authentication tokens, and session info.
    Can be initialized with either a dict or individual objects.
    """
    user = UserMeSerializer(read_only=True)
    tokens = TokensSerializer(read_only=True)
    session_profile = SessionProfileSerializer(read_only=True)

    def __init__(self, instance=None, user=None, tokens=None, session_profile=None, **kwargs):
        """
        Initialize serializer with either dict or individual objects.

        Args:
            instance: Dict with user, tokens, session_profile keys (traditional way)
            user: User object (direct way)
            tokens: TokenPair object (direct way)
            session_profile: UserSessionProfile object (direct way)
        """
        if instance is None and all(x is not None for x in [user, tokens, session_profile]):
            # Direct object passing
            instance = {
                'user': user,
                'tokens': tokens,
                'session_profile': session_profile
            }
        super().__init__(instance, **kwargs)


class TokenVerifyOutputSerializer(serializers.Serializer):
    """
    Output serializer for token verification response.

    Returns user profile data and session info, similar to login.
    """
    user = UserMeSerializer(read_only=True)
    session_profile = SessionProfileSerializer(read_only=True, required=False)


class RefreshTokenInputSerializer(serializers.Serializer):
    """
    Input serializer for token refresh.

    Performs basic field validation only.
    """
    refresh_token = serializers.CharField(required=True, write_only=True)


class RefreshTokenOutputSerializer(serializers.Serializer):
    """
    Output serializer for token refresh response.

    Reuses existing TokensSerializer and takes objects directly.
    TokensSerializer can handle both TokenPair dataclass and dict formats
    through its to_representation() method.
    """
    tokens = TokensSerializer(read_only=True)

    def __init__(self, tokens=None, **kwargs):
        """
        Initialize with TokenPair object directly.

        Args:
            tokens: TokenPair object (not dict) - TokensSerializer handles conversion
        """
        if tokens is not None:
            instance = {'tokens': tokens}
            super().__init__(instance, **kwargs)
        else:
            super().__init__(**kwargs)


class EmailSSORequestSerializer(serializers.Serializer):
    """Input serializer for requesting an email-based single sign-on link."""
    email = serializers.EmailField(required=True, help_text="Registered user email")
    redirect_path = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Optional frontend-relative path to continue after sign-in"
    )


class EmailSSOVerifySerializer(serializers.Serializer):
    """Input serializer for verifying an email SSO token."""
    token = serializers.CharField(required=True, help_text="Signed token from email link")


class EmailSSOOutputSerializer(serializers.Serializer):
    """Output serializer describing the SSO email dispatch result."""
    email = serializers.EmailField(read_only=True)
    account_exists = serializers.BooleanField(read_only=True)
    delivered = serializers.BooleanField(read_only=True)
    expires_in = serializers.IntegerField(read_only=True)
    login_url = serializers.URLField(read_only=True, allow_null=True)

    def __init__(self, result=None, **kwargs):
        if result is not None:
            instance = {
                'email': result.email,
                'account_exists': result.account_exists,
                'delivered': result.delivered,
                'expires_in': result.expires_in,
                'login_url': result.login_url,
            }
            super().__init__(instance, **kwargs)
        else:
            super().__init__(**kwargs)


class ResetPasswordInputSerializer(serializers.Serializer):
    """
    Input serializer for password reset.

    Performs basic field validation only.
    Business logic validation is handled in services.
    User is already authenticated via Bearer token.
    """
    new_password = serializers.CharField(
        required=True,
        min_length=1,
        write_only=True,
        help_text="New password"
    )

