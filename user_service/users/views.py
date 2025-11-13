"""
Users views.

Handles HTTP requests and delegates business logic to services.
"""
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.request import Request
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from drf_spectacular.utils import extend_schema, OpenApiResponse

from user_service.utils import APIResponse
from authentication.services import TokenService
from .serializers import (
    PublicProfileInputSerializer,
    PublicProfileOutputSerializer,
)
from .services import PublicProfileService, ValidationError


@method_decorator(csrf_exempt, name='dispatch')
class PublicProfileView(APIView):
    """
    API view for fetching public user profiles.

    Handles GET requests to retrieve basic public profile information
    for a given user_id. This endpoint requires authentication.
    """
    permission_classes = []  # Requires authentication but handled manually

    @extend_schema(
        summary="Get public user profile",
        description="Retrieve basic public profile information (display name, etc.) for a given user ID. Requires authentication.",
        parameters=[PublicProfileInputSerializer],
        responses={
            200: OpenApiResponse(response=PublicProfileOutputSerializer, description="Profile retrieved successfully"),
            400: OpenApiResponse(description="Invalid input data"),
            401: OpenApiResponse(description="Authentication required"),
            404: OpenApiResponse(description="User not found"),
        },
        tags=["Users"]
    )
    def get(self, request: Request) -> Response:
        """
        Get public profile for a user.

        Args:
            request: HTTP request with user_id query parameter

        Returns:
            Response: Standardized API response with public user data
        """
        # Verify authentication - this endpoint is protected
        try:
            accessing_user, accessing_session = TokenService.verify_token_and_get_user_data(request)
            # Track: accessing_user.id is viewing profile of user_id
            # You can log this access for audit/analytics
        except ValidationError as e:
            # Authentication required - return 401 if token is invalid/missing
            return APIResponse.unauthorized(str(e))

        # Validate input from query parameters
        input_serializer = PublicProfileInputSerializer(data=request.query_params)
        if not input_serializer.is_valid():
            return APIResponse.validation_error(
                "Invalid input data",
                details=input_serializer.errors
            )

        try:
            # Get user through service layer
            validated_data = input_serializer.validated_data
            user = PublicProfileService.get_public_profile(
                user_id=validated_data['user_id']
            )

            # Format successful response
            output_serializer = PublicProfileOutputSerializer({'user': user})
            return APIResponse.success(
                data=output_serializer.data,
                message="Public profile retrieved successfully"
            )

        except ValidationError as e:
            error_message = str(e)

            # Return 404 for user not found
            if "user not found" in error_message.lower():
                return APIResponse.not_found(error_message)
            else:
                return APIResponse.bad_request(error_message)
