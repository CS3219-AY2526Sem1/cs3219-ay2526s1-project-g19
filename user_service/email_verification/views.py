"""
Email verification API endpoints.

Provides REST API endpoints for:
- Sending/resending verification emails
- Checking email verification status
"""
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from allauth.account.models import EmailAddress
from allauth.account.utils import send_email_confirmation
from drf_spectacular.utils import extend_schema, OpenApiResponse


@extend_schema(
    summary="Send email verification",
    description="Send or resend email verification link to the authenticated user's email address.",
    responses={
        200: OpenApiResponse(description="Verification email sent successfully"),
        400: OpenApiResponse(description="Email already verified or error occurred"),
    },
    tags=["Email Verification"]
)
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_verification_email(request):
    """
    Send or resend verification email to the user.

    Returns:
        200: Verification email sent successfully
        400: Email already verified or error occurred
    """
    user = request.user

    # Check if email is already verified
    if user.is_verified:
        return Response(
            {"detail": "Email is already verified."},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        # Get or create EmailAddress entry
        email_address, _ = EmailAddress.objects.get_or_create(
            user=user,
            email=user.email,
            defaults={'verified': False, 'primary': True}
        )

        if email_address.verified:
            # Update user model if out of sync
            if not user.is_verified:
                user.is_verified = True
                user.save(update_fields=['is_verified'])

            return Response(
                {"detail": "Email is already verified."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Send verification email
        send_email_confirmation(request, user, signup=False)

        return Response(
            {
                "detail": "Verification email sent successfully.",
                "email": user.email
            },
            status=status.HTTP_200_OK
        )

    except Exception as e:
        return Response(
            {"detail": f"Failed to send verification email: {str(e)}"},
            status=status.HTTP_400_BAD_REQUEST
        )


@extend_schema(
    summary="Get email verification status",
    description="Check if the authenticated user's email is verified.",
    responses={
        200: OpenApiResponse(
            description="Email verification status",
            response={
                "type": "object",
                "properties": {
                    "is_verified": {"type": "boolean"},
                    "email": {"type": "string", "format": "email"}
                }
            }
        ),
    },
    tags=["Email Verification"]
)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_verification_status(request):
    """
    Get the email verification status for the authenticated user.

    Returns:
        200: Email verification status
    """
    user = request.user

    # Check allauth's EmailAddress model for the most up-to-date status
    try:
        email_address = EmailAddress.objects.get(user=user, email=user.email)
        is_verified = email_address.verified

        # Sync if out of sync
        if is_verified != user.is_verified:
            user.is_verified = is_verified
            user.save(update_fields=['is_verified'])
    except EmailAddress.DoesNotExist:
        is_verified = user.is_verified

    return Response(
        {
            "is_verified": is_verified,
            "email": user.email
        },
        status=status.HTTP_200_OK
    )
