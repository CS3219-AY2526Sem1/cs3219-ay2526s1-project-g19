from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()

class UserProfileSerializer(serializers.ModelSerializer):
    """
    Serializer for user profile update operations.

    Allows updating of non-sensitive profile information.
    """
    display_name = serializers.CharField(
        source='first_name',
        required=False,
        help_text="User's display name"
    )

    class Meta:
        model = User
        fields = [
            'id', 'email', 'display_name', 'phone_number',
            'date_of_birth', 'is_verified', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'email', 'is_verified', 'created_at', 'updated_at']

class UserMeSerializer(serializers.ModelSerializer):
    """
    Serializer for current user information (GET /api/users/me).

    Read-only serializer for retrieving authenticated user's profile.
    """
    display_name = serializers.CharField(
        source='first_name',
        read_only=True,
        help_text="User's display name"
    )

    class Meta:
        model = User
        fields = [
            'id', 'email', 'display_name', 'phone_number',
            'date_of_birth', 'is_verified', 'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'email', 'is_verified', 'created_at', 'updated_at'
        ]