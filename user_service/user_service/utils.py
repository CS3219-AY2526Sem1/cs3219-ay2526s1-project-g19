"""
Utility functions for consistent API responses.

Provides standardized response formats across the application.
"""
from typing import Any, Dict, Optional
from rest_framework.response import Response
from rest_framework import status

class APIResponse:
    """Utility class for consistent API response formatting."""

    @staticmethod
    def success(
        data: Any = None,
        message: str = "Success",
        status_code: int = status.HTTP_200_OK
    ) -> Response:
        """
        Create a standardized success response.

        Args:
            data: Response data
            message: Success message
            status_code: HTTP status code

        Returns:
            Response: Formatted success response
        """
        response_data = {
            "success": True,
            "message": message,
            "data": data
        }
        return Response(response_data, status=status_code)

    @staticmethod
    def created(data: Any = None, message: str = "Created successfully") -> Response:
        """
        Create a standardized 201 Created response.

        Args:
            data: Response data
            message: Success message

        Returns:
            Response: Formatted created response
        """
        return APIResponse.success(data, message, status.HTTP_201_CREATED)

    @staticmethod
    def error(
        message: str,
        details: Optional[Dict[str, Any]] = None,
        status_code: int = status.HTTP_400_BAD_REQUEST
    ) -> Response:
        """
        Create a standardized error response.

        Args:
            message: Error message
            details: Additional error details (e.g., validation errors)
            status_code: HTTP status code

        Returns:
            Response: Formatted error response
        """
        response_data = {
            "success": False,
            "error": {
                "message": message
            }
        }

        if details:
            response_data["error"]["details"] = details

        return Response(response_data, status=status_code)

    @staticmethod
    def bad_request(message: str, details: Optional[Dict[str, Any]] = None) -> Response:
        """
        Create a standardized 400 Bad Request response.

        Args:
            message: Error message
            details: Additional error details

        Returns:
            Response: Formatted bad request response
        """
        return APIResponse.error(message, details, status.HTTP_400_BAD_REQUEST)

    @staticmethod
    def validation_error(message: str, details: Optional[Dict[str, Any]] = None) -> Response:
        """
        Create a standardized validation error response.

        Args:
            message: Error message
            details: Validation error details

        Returns:
            Response: Formatted validation error response
        """
        return APIResponse.error(
            message="Validation failed" if not message else message,
            details=details,
            status_code=status.HTTP_400_BAD_REQUEST
        )

    @staticmethod
    def conflict(message: str = "Resource already exists") -> Response:
        """
        Create a standardized 409 Conflict response.

        Args:
            message: Error message

        Returns:
            Response: Formatted conflict response
        """
        return APIResponse.error(message, status_code=status.HTTP_409_CONFLICT)

    @staticmethod
    def unauthorized(message: str = "Authentication required") -> Response:
        """
        Create a standardized 401 Unauthorized response.

        Args:
            message: Error message

        Returns:
            Response: Formatted unauthorized response
        """
        return APIResponse.error(message, status_code=status.HTTP_401_UNAUTHORIZED)

    @staticmethod
    def forbidden(message: str = "Permission denied") -> Response:
        """
        Create a standardized 403 Forbidden response.

        Args:
            message: Error message

        Returns:
            Response: Formatted forbidden response
        """
        return APIResponse.error(message, status_code=status.HTTP_403_FORBIDDEN)

    @staticmethod
    def not_found(message: str = "Resource not found") -> Response:
        """
        Create a standardized 404 Not Found response.

        Args:
            message: Error message

        Returns:
            Response: Formatted not found response
        """
        return APIResponse.error(message, status_code=status.HTTP_404_NOT_FOUND)

    @staticmethod
    def too_many_requests(message: str = "Too many requests") -> Response:
        """
        Create a standardized 429 Too Many Requests response.

        Args:
            message: Error message

        Returns:
            Response: Formatted too many requests response
        """
        return APIResponse.error(message, status_code=status.HTTP_429_TOO_MANY_REQUESTS)

    @staticmethod
    def internal_error(message: str = "Internal server error") -> Response:
        """
        Create a standardized 500 Internal Server Error response.

        Args:
            message: Error message

        Returns:
            Response: Formatted internal error response
        """
        return APIResponse.error(message, status_code=status.HTTP_500_INTERNAL_SERVER_ERROR)