"""
Execution service views for code execution and testing.
"""
import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from drf_spectacular.utils import extend_schema
from dataclasses import asdict

from .serializers import (
    ExecuteRequestSerializer,
    ExecuteResponseSerializer,
    ExecuteTestsRequestSerializer,
    TestExecutionResponseSerializer,
    LanguagesResponseSerializer
)
from .services import ExecutionService

logger = logging.getLogger(__name__)

class ExecuteView(APIView):
    """
    Execute a single code snippet with optional input.
    """
    
    @extend_schema(
        summary="Execute code",
        description="Execute a single code snippet and return the output.",
        request=ExecuteRequestSerializer,
        responses={
            200: ExecuteResponseSerializer,
            400: {'description': 'Invalid input'},
            502: {'description': 'Execution service error'}
        },
        tags=['execution']
    )
    def post(self, request):
        """Execute code and return results."""
        # Validate input using serializer
        serializer = ExecuteRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'error': 'Invalid input', 'details': serializer.errors}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Execute code using service layer
            execution_service = ExecutionService()
            result = execution_service.execute_single(
                language_id=serializer.validated_data['language_id'],
                source_code=serializer.validated_data['source_code'],
                stdin=serializer.validated_data.get('stdin', '')
            )
            
            # Serialize response
            response_serializer = ExecuteResponseSerializer(data=asdict(result))
            if response_serializer.is_valid():
                logger.info(f"Code executed successfully: {result.status}")
                return Response(response_serializer.validated_data, status=status.HTTP_200_OK)
            else:
                logger.error(f"Response serialization error: {response_serializer.errors}")
                return Response(
                    {'error': 'response_serialization_failed'}, 
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
        except Exception as e:
            logger.error(f"Execution error: {e}")
            return Response(
                {'error': 'execution_failed', 'details': str(e)}, 
                status=status.HTTP_502_BAD_GATEWAY
            )


class ExecuteTestsView(APIView):
    """
    Execute code against official test cases from question service.
    """
    
    @extend_schema(
        summary="Execute code against test cases",
        description="Execute code against official test cases from question service.",
        request=ExecuteTestsRequestSerializer,
        responses={
            200: TestExecutionResponseSerializer,
            400: {'description': 'Invalid input'},
            502: {'description': 'Service error'}
        },
        tags=['execution']
    )
    def post(self, request):
        """Execute code against test cases."""
        # Validate input using serializer
        serializer = ExecuteTestsRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'error': 'Invalid input', 'details': serializer.errors}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Execute tests using service layer
            execution_service = ExecutionService()
            result = execution_service.execute_tests(
                language_id=serializer.validated_data['language_id'],
                source_code=serializer.validated_data['source_code'],
                question_id=str(serializer.validated_data['question_id'])
            )
            
            # Serialize response
            response_serializer = TestExecutionResponseSerializer(data=asdict(result))
            if response_serializer.is_valid():
                logger.info(f"Test execution completed: {result.summary.passed}/{result.summary.total} passed")
                return Response(response_serializer.validated_data, status=status.HTTP_200_OK)
            else:
                logger.error(f"Response serialization error: {response_serializer.errors}")
                return Response(
                    {'error': 'response_serialization_failed'}, 
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
        except ValueError as e:
            logger.error(f"Validation error: {e}")
            return Response(
                {'error': 'validation_failed', 'details': str(e)}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.error(f"Test execution error: {e}")
            return Response(
                {'error': 'test_execution_failed', 'details': str(e)}, 
                status=status.HTTP_502_BAD_GATEWAY
            )


class LanguagesView(APIView):
    """
    Get supported programming languages.
    """
    
    @extend_schema(
        summary="Get supported languages",
        description="Get list of supported programming languages with their Judge0 IDs.",
        responses={
            200: LanguagesResponseSerializer
        },
        tags=['execution']
    )
    def get(self, request):
        """Get supported programming languages."""
        try:
            # Get languages using service layer
            execution_service = ExecutionService()
            languages = execution_service.get_supported_languages()
            
            # Serialize response
            response_serializer = LanguagesResponseSerializer(data={'languages': [asdict(lang) for lang in languages]})
            if response_serializer.is_valid():
                return Response(response_serializer.validated_data, status=status.HTTP_200_OK)
            else:
                logger.error(f"Response serialization error: {response_serializer.errors}")
                return Response(
                    {'error': 'response_serialization_failed'}, 
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
        except Exception as e:
            logger.error(f"Languages fetch error: {e}")
            return Response(
                {'error': 'languages_fetch_failed', 'details': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


