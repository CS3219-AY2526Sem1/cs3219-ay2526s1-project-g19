"""
Authentication views.

Handles HTTP requests and delegates business logic to services.
"""
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.request import Request
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from drf_spectacular.utils import extend_schema, OpenApiResponse

from user_service.utils import APIResponse
from .serializers import (
    UserRegistrationInputSerializer,
    UserRegistrationOutputSerializer,
    UserLoginInputSerializer,
    UserLoginOutputSerializer,
    TokenVerifyOutputSerializer,
    RefreshTokenInputSerializer,
    RefreshTokenOutputSerializer,
    EmailSSORequestSerializer,
    EmailSSOOutputSerializer,
    EmailSSOVerifySerializer,
    ResetPasswordInputSerializer
)
from .services import (
    UserRegistrationService,
    UserLoginService,
    UserLogoutService,
    TokenService,
    ValidationError,
    EmailSSOService,
    PasswordResetService
)

@method_decorator(csrf_exempt, name='dispatch')
class UserRegistrationView(APIView):
    """
    API view for user registration.

    Handles POST requests to create new user accounts.
    Delegates business logic to UserRegistrationService.
    """
    permission_classes = [AllowAny]

    @extend_schema(
        summary="Register new user",
        description="Create a new user account with email, password, and display name",
        request=UserRegistrationInputSerializer,
        responses={
            201: OpenApiResponse(response=UserRegistrationOutputSerializer, description="User registered successfully"),
            400: OpenApiResponse(description="Invalid input data or validation error"),
        },
        tags=["Authentication"]
    )
    def post(self, request: Request) -> Response:
        """
        Create a new user account.

        Args:
            request: HTTP request containing user registration data

        Returns:
            Response: Standardized API response
        """
        # Validate input
        input_serializer = UserRegistrationInputSerializer(data=request.data)
        if not input_serializer.is_valid():
            return APIResponse.validation_error(
                "Invalid input data",
                details=input_serializer.errors
            )

        try:
            # Process registration through service layer
            validated_data = input_serializer.validated_data
            user = UserRegistrationService.register_user(
                email=validated_data['email'],
                password=validated_data['password'],
                display_name=validated_data['display_name']
            )

            # Format successful response
            output_serializer = UserRegistrationOutputSerializer({'user': user})
            return APIResponse.created(
                data=output_serializer.data,
                message="User registered successfully"
            )

        except ValidationError as e:
            return APIResponse.bad_request(str(e))


@method_decorator(csrf_exempt, name='dispatch')
class UserLoginView(APIView):
    """
    API view for user login.

    Handles POST requests to authenticate users and generate tokens.
    Delegates business logic to UserLoginService.
    """
    permission_classes = [AllowAny]

    @extend_schema(
        summary="User login",
        description="Authenticate user with email and password, returns JWT tokens and session profile",
        request=UserLoginInputSerializer,
        responses={
            200: OpenApiResponse(response=UserLoginOutputSerializer, description="Login successful"),
            400: OpenApiResponse(description="Invalid input data"),
            401: OpenApiResponse(description="Invalid email or password"),
            403: OpenApiResponse(description="Account is disabled"),
            429: OpenApiResponse(description="Too many failed login attempts"),
        },
        tags=["Authentication"]
    )
    def post(self, request: Request) -> Response:
        """
        Authenticate user and generate login tokens.

        Args:
            request: HTTP request containing login credentials

        Returns:
            Response: Standardized API response
        """
        # Validate input
        input_serializer = UserLoginInputSerializer(data=request.data)
        if not input_serializer.is_valid():
            return APIResponse.validation_error(
                "Invalid input data",
                details=input_serializer.errors
            )

        try:
            # Get client metadata
            ip_address = self._get_client_ip(request)
            user_agent = request.META.get('HTTP_USER_AGENT', '')

            # Process login through service layer
            validated_data = input_serializer.validated_data
            user, tokens, session_profile = UserLoginService.login_user(
                request=request,
                email=validated_data['email'],
                password=validated_data['password'],
                ip_address=ip_address,
                user_agent=user_agent
            )

            # Format successful response - pass objects directly
            output_serializer = UserLoginOutputSerializer(
                user=user,
                tokens=tokens,
                session_profile=session_profile
            )
            return APIResponse.success(
                data=output_serializer.data,
                message="Login successful"
            )

        except ValidationError as e:
            error_message = str(e)

            # Return specific status codes based on error type
            if "too many failed" in error_message.lower():
                return APIResponse.too_many_requests(error_message)
            elif "invalid email or password" in error_message.lower():
                return APIResponse.unauthorized(error_message)
            elif "account is disabled" in error_message.lower():
                return APIResponse.forbidden(error_message)
            else:
                return APIResponse.bad_request(error_message)

    def _get_client_ip(self, request: Request) -> str:
        """
        Get client IP address from request.

        Args:
            request: HTTP request

        Returns:
            str: Client IP address
        """
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0].strip()
        else:
            ip = request.META.get('REMOTE_ADDR', '')
        return ip


@method_decorator(csrf_exempt, name='dispatch')
class UserLogoutView(APIView):
    """
    API view for user logout.

    Handles POST requests to logout users and invalidate sessions.
    Delegates business logic to UserLogoutService.
    """
    permission_classes = []  # Requires authentication but handled manually

    @extend_schema(
        summary="User logout",
        description="Logout user and invalidate all sessions",
        request=None,
        responses={
            200: OpenApiResponse(description="Logout successful"),
            400: OpenApiResponse(description="Logout failed"),
            401: OpenApiResponse(description="Authentication required"),
        },
        tags=["Authentication"]
    )
    def post(self, request: Request) -> Response:
        """
        Logout user and invalidate sessions.

        Args:
            request: HTTP request (empty body)

        Returns:
            Response: Standardized API response
        """
        # Check if user is authenticated
        if not request.user or not request.user.is_authenticated:
            return APIResponse.unauthorized("Authentication required")

        try:
            # Process logout through service layer
            UserLogoutService.logout_user(request, request.user)

            return APIResponse.success(
                message="Logout successful"
            )

        except ValidationError as e:
            return APIResponse.bad_request(str(e))


class TokenVerifyView(APIView):
    """
    API view for token verification.

    Handles GET requests to verify JWT tokens and return user data.
    Delegates business logic to TokenVerifyService.
    """
    permission_classes = []  # Requires authentication but handled manually

    @extend_schema(
        summary="Verify JWT token",
        description="Verify JWT access token and return user data",
        request=None,
        responses={
            200: OpenApiResponse(response=TokenVerifyOutputSerializer, description="Token verified successfully"),
            401: OpenApiResponse(description="Missing/invalid/expired JWT"),
            403: OpenApiResponse(description="User account is disabled"),
        },
        tags=["Authentication"]
    )
    def get(self, request: Request) -> Response:
        """
        Verify JWT token and return user data.

        Args:
            request: HTTP request with Authorization header

        Returns:
            Response: Standardized API response with user data
        """
        try:
            # Get user data through service layer (handles authentication check internally)
            user, session_profile = TokenService.verify_token_and_get_user_data(request)

            # Format successful response
            user_data = {
                'user': user,
                'session_profile': session_profile
            }
            output_serializer = TokenVerifyOutputSerializer(user_data)
            return APIResponse.success(
                data=output_serializer.data,
                message="Token verified successfully"
            )

        except ValidationError as e:
            error_message = str(e)

            # Return appropriate status codes based on error type
            if "authentication required" in error_message.lower():
                return APIResponse.unauthorized(error_message)
            else:
                return APIResponse.forbidden(error_message)


@method_decorator(csrf_exempt, name='dispatch')
class RefreshTokenView(APIView):
    """
    API view for token refresh.

    Handles POST requests to refresh JWT tokens.
    Delegates business logic to TokenRefreshService.
    """
    permission_classes = [AllowAny]

    @extend_schema(
        summary="Refresh access token",
        description="Generate new access token using refresh token",
        request=RefreshTokenInputSerializer,
        responses={
            200: OpenApiResponse(response=RefreshTokenOutputSerializer, description="Token refreshed"),
            400: OpenApiResponse(description="Invalid refresh token"),
        },
        tags=["Authentication"]
    )
    def post(self, request: Request) -> Response:
        """
        Refresh access token using refresh token.

        Args:
            request: HTTP request containing refresh token

        Returns:
            Response: Standardized API response with new tokens
        """
        # Validate input
        input_serializer = RefreshTokenInputSerializer(data=request.data)
        if not input_serializer.is_valid():
            return APIResponse.validation_error("Invalid input", details=input_serializer.errors)

        try:
            # Process through service
            validated_data = input_serializer.validated_data
            new_tokens = TokenService.refresh_access_token(
                validated_data['refresh_token']
            )

            # Pass TokenPair object directly to serializer
            output_serializer = RefreshTokenOutputSerializer(
                tokens=new_tokens
            )

            return APIResponse.success(
                data=output_serializer.data,
                message="Token refreshed successfully"
            )

        except ValidationError as e:
            return APIResponse.bad_request(str(e))


@method_decorator(csrf_exempt, name='dispatch')
class EmailSSORequestView(APIView):
    """API view for dispatching email-based single sign-on links."""

    permission_classes = [AllowAny]

    @extend_schema(
        summary="Send magic sign-in email",
        description="Generate a time-bound email single sign-on link and deliver it to the user.",
        request=EmailSSORequestSerializer,
        responses={
            202: OpenApiResponse(response=EmailSSOOutputSerializer, description="Magic link dispatched"),
            400: OpenApiResponse(description="Invalid request payload"),
        },
        tags=["Authentication"]
    )
    def post(self, request: Request) -> Response:
        serializer = EmailSSORequestSerializer(data=request.data)
        if not serializer.is_valid():
            return APIResponse.validation_error("Invalid input", details=serializer.errors)

        try:
            payload = serializer.validated_data
            result = EmailSSOService.send_sso_link(
                email=payload['email'],
                redirect_path=payload.get('redirect_path')
            )

            output_serializer = EmailSSOOutputSerializer(result=result)

            # Provide clear message based on account existence
            if result.account_exists:
                message = "Sign-in link has been sent to your email."
            else:
                message = "No account found with this email address."

            return APIResponse.success(
                data=output_serializer.data,
                message=message,
                status_code=status.HTTP_202_ACCEPTED
            )
        except ValidationError as exc:
            return APIResponse.bad_request(str(exc))


@method_decorator(csrf_exempt, name='dispatch')
class EmailSSOVerifyView(APIView):
    """API view for verifying email SSO tokens and logging in users."""

    permission_classes = [AllowAny]

    @extend_schema(
        summary="Verify email SSO token",
        description="Verify email SSO token and log in user, returning JWT tokens and session profile",
        request=EmailSSOVerifySerializer,
        responses={
            200: OpenApiResponse(response=UserLoginOutputSerializer, description="Login successful"),
            400: OpenApiResponse(description="Invalid or expired token"),
            401: OpenApiResponse(description="User not found or inactive"),
        },
        tags=["Authentication"]
    )
    def post(self, request: Request) -> Response:
        """
        Verify email SSO token and log in user.

        Args:
            request: HTTP request containing token

        Returns:
            Response: Standardized API response with user data, tokens, and session
        """
        # Validate input
        input_serializer = EmailSSOVerifySerializer(data=request.data)
        if not input_serializer.is_valid():
            return APIResponse.validation_error(
                "Invalid input data",
                details=input_serializer.errors
            )

        try:
            # Get client metadata
            ip_address = self._get_client_ip(request)
            user_agent = request.META.get('HTTP_USER_AGENT', '')

            # Verify token and login through service layer
            validated_data = input_serializer.validated_data


            user, tokens, session_profile = EmailSSOService.verify_and_login(
                request=request,
                token=validated_data['token'],
                ip_address=ip_address,
                user_agent=user_agent
            )

            # Format successful response
            output_serializer = UserLoginOutputSerializer(
                user=user,
                tokens=tokens,
                session_profile=session_profile
            )
            return APIResponse.success(
                data=output_serializer.data,
                message="Login successful"
            )

        except ValidationError as e:
            error_message = str(e)

            # Return specific status codes based on error type
            if "expired" in error_message.lower() or "invalid" in error_message.lower():
                return APIResponse.bad_request(error_message)
            elif "user not found" in error_message.lower():
                return APIResponse.unauthorized(error_message)
            elif "account is disabled" in error_message.lower():
                return APIResponse.forbidden(error_message)
            else:
                return APIResponse.bad_request(error_message)

    def _get_client_ip(self, request: Request) -> str:
        """
        Get client IP address from request.

        Args:
            request: HTTP request

        Returns:
            str: Client IP address
        """
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0].strip()
        else:
            ip = request.META.get('REMOTE_ADDR', '')
        return ip


@method_decorator(csrf_exempt, name='dispatch')
class ResetPasswordView(APIView):
    """
    API view for password reset.

    Handles PUT requests to reset user password.
    Requires Bearer authentication.
    """
    permission_classes = []  # Requires authentication but handled manually

    @extend_schema(
        summary="Reset password",
        description=(
            "Reset user password (requires Bearer authentication). "
            "**IMPORTANT:** All active sessions will be invalidated for security purposes. "
            "You will need to login again with your new password to get new tokens."
        ),
        request=ResetPasswordInputSerializer,
        responses={
            200: OpenApiResponse(description="Password reset successful. All sessions invalidated."),
            400: OpenApiResponse(description="Invalid input data or validation error"),
            401: OpenApiResponse(description="Authentication required"),
        },
        tags=["Authentication"]
    )
    def put(self, request: Request) -> Response:
        """
        Reset user password.

        Args:
            request: HTTP request containing new password

        Returns:
            Response: Standardized API response
        """
        # Check if user is authenticated
        if not request.user or not request.user.is_authenticated:
            return APIResponse.unauthorized("Authentication required")

        # Validate input
        input_serializer = ResetPasswordInputSerializer(data=request.data)
        if not input_serializer.is_valid():
            return APIResponse.validation_error(
                "Invalid input data",
                details=input_serializer.errors
            )

        try:
            # Process password reset through service layer
            validated_data = input_serializer.validated_data
            PasswordResetService.reset_password(
                user=request.user,
                new_password=validated_data['new_password']
            )

            return APIResponse.success(
                message="Password reset successful. All active sessions have been invalidated. Please login again with your new password."
            )

        except ValidationError as e:
            return APIResponse.bad_request(str(e))
