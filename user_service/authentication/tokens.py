"""
Token data structures and utilities.

Contains dataclasses and utilities for JWT token management.
"""
from dataclasses import dataclass
from typing import Dict
from datetime import datetime
from django.contrib.auth.models import AbstractUser
from rest_framework_simplejwt.tokens import RefreshToken


@dataclass
class AccessToken:
    """
    Dataclass for access token with expiration information.
    """
    token: str
    expires_at: datetime


@dataclass
class RefreshTokenData:
    """
    Dataclass for refresh token with expiration information.
    """
    token: str
    expires_at: datetime


@dataclass
class TokenPair:
    """
    Dataclass for JWT token pair (access + refresh).

    Uses AccessToken and RefreshTokenData dataclasses for consistency.
    """
    access_token: AccessToken
    refresh_token: RefreshTokenData

    def to_dict(self) -> Dict:
        """
        Convert token pair to dictionary format.

        Returns:
            Dict: Dictionary with access_token and refresh_token data
        """
        return {
            'access_token': {
                'token': self.access_token.token,
                'expires_at': self.access_token.expires_at
            },
            'refresh_token': {
                'token': self.refresh_token.token,
                'expires_at': self.refresh_token.expires_at
            }
        }

    @classmethod
    def generate_for_user(cls, user: AbstractUser, session_profile_id: str) -> 'TokenPair':
        """
        Generate a new token pair for a user with session tracking.

        Args:
            user: User instance to generate tokens for
            session_profile_id: Session profile ID to include in both tokens

        Returns:
            TokenPair: New token pair instance with profile_session_id embedded and expiration times
        """
        refresh = RefreshToken.for_user(user)

        # Add session profile ID to token payload (appears in both access and refresh tokens)
        refresh['profile_session_id'] = session_profile_id

        # Extract expiration times from JWT tokens
        access_token_expires_at = datetime.fromtimestamp(refresh.access_token['exp'])
        refresh_token_expires_at = datetime.fromtimestamp(refresh['exp'])

        return cls(
            access_token=AccessToken(
                token=str(refresh.access_token),
                expires_at=access_token_expires_at
            ),
            refresh_token=RefreshTokenData(
                token=str(refresh),
                expires_at=refresh_token_expires_at
            )
        )

    def __str__(self) -> str:
        """String representation showing truncated tokens."""
        return f"TokenPair(access={self.access_token.token[:20]}..., refresh={self.refresh_token.token[:20]}...)"