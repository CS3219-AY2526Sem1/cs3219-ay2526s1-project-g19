"""
Service layer for execution service operations.
"""
import os
import requests
import logging
from typing import List, Optional
from dataclasses import asdict

from .serializers import (
    Judge0Submission,
    Judge0Response,
    TestCase,
    TestResult,
    TestSummary,
    TestExecutionResponse,
    LanguageInfo,
    judge0_response_to_dataclass,
    test_case_to_dataclass,
    create_test_result,
    create_error_test_result
)

logger = logging.getLogger(__name__)

# Configuration
JUDGE0_URL = os.getenv('JUDGE0_URL', 'http://judge0:2358')
JUDGE0_API_KEY = os.getenv('JUDGE0_API_KEY', '')
QUESTION_SERVICE_URL = os.getenv('QUESTION_SERVICE_URL', 'http://question-service:8000')

# Language mapping
LANGUAGE_MAP = {
    'python3': 71,
    'python': 71,
    'javascript': 63,
    'node': 63,
    'java': 62,
    'cpp': 54,
    'c': 50,
    'csharp': 51,
    'go': 60,
    'rust': 73,
    'php': 68,
    'ruby': 72,
    'swift': 83,
    'kotlin': 78,
    'scala': 81,
    'typescript': 74,
}


class Judge0Service:
    """Service for interacting with Judge0 API."""
    
    def __init__(self):
        self.base_url = JUDGE0_URL
        self.api_key = JUDGE0_API_KEY
        self.headers = self._get_headers()
    
    def _get_headers(self) -> dict:
        """Get headers for Judge0 API requests."""
        headers = {}
        if self.api_key:
            headers['X-RapidAPI-Key'] = self.api_key
            headers['X-RapidAPI-Host'] = 'ce.judge0.com'
        return headers
    
    def execute_code(self, submission: Judge0Submission) -> Judge0Response:
        """
        Execute code using Judge0 API.
        
        Args:
            submission: Judge0Submission dataclass with code and parameters
            
        Returns:
            Judge0Response dataclass with execution results
            
        Raises:
            requests.RequestException: If Judge0 API request fails
        """
        try:
            payload = asdict(submission)
            url = f"{self.base_url}/submissions"
            
            response = requests.post(
                f"{url}?base64_encoded=false&wait=true",
                json=payload,
                headers=self.headers,
                timeout=20
            )
            
            if response.status_code >= 400:
                logger.error(f"Judge0 error: {response.status_code} - {response.text}")
                raise requests.RequestException(f"Judge0 API error: {response.status_code}")
            
            data = response.json()
            return judge0_response_to_dataclass(data)
            
        except requests.exceptions.Timeout:
            logger.error("Judge0 execution timeout")
            raise requests.RequestException("Execution timeout")
        except requests.exceptions.RequestException as e:
            logger.error(f"Judge0 request error: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected Judge0 error: {e}")
            raise requests.RequestException(f"Judge0 service error: {str(e)}")


class QuestionService:
    """Service for interacting with question service."""
    
    def __init__(self):
        self.base_url = QUESTION_SERVICE_URL
    
    def get_test_cases(self, question_id: str) -> List[TestCase]:
        """
        Fetch test cases for a question.
        
        Args:
            question_id: UUID of the question
            
        Returns:
            List of TestCase dataclasses
            
        Raises:
            requests.RequestException: If question service request fails
        """
        try:
            url = f"{self.base_url}/api/questions/{question_id}?fields=examples"
            response = requests.get(url, timeout=10)
            
            if response.status_code != 200:
                logger.error(f"Question service error: {response.status_code}")
                raise requests.RequestException(f"Question service error: {response.status_code}")
            
            data = response.json()
            examples = data.get('examples', [])
            
            if not examples:
                raise ValueError("No test cases found for question")
            
            return [test_case_to_dataclass(example) for example in examples]
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Question service request error: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected question service error: {e}")
            raise requests.RequestException(f"Question service error: {str(e)}")


class ExecutionService:
    """Main service for code execution operations."""
    
    def __init__(self):
        self.judge0_service = Judge0Service()
        self.question_service = QuestionService()
    
    def execute_single(self, language_id: int, source_code: str, stdin: str = "") -> Judge0Response:
        """
        Execute a single code snippet.
        
        Args:
            language_id: Judge0 language ID
            source_code: Source code to execute
            stdin: Standard input for the program
            
        Returns:
            Judge0Response with execution results
        """
        submission = Judge0Submission(
            language_id=language_id,
            source_code=source_code,
            stdin=stdin
        )
        
        return self.judge0_service.execute_code(submission)
    
    def execute_tests(
        self, 
        language_id: int, 
        source_code: str, 
        question_id: str
    ) -> TestExecutionResponse:
        """
        Execute code against test cases.
        
        Args:
            language_id: Judge0 language ID
            source_code: Source code to execute
            question_id: Question ID to fetch test cases from
            
        Returns:
            TestExecutionResponse with all test results
        """
        # Fetch test cases
        test_cases = self.question_service.get_test_cases(question_id)
        
        # Execute each test case
        results = []
        for test_case in test_cases:
            try:
                submission = Judge0Submission(
                    language_id=language_id,
                    source_code=source_code,
                    stdin=test_case.input
                )
                
                judge0_response = self.judge0_service.execute_code(submission)
                
                # Create test result
                result = create_test_result(
                    ok=judge0_response.stdout.strip() == test_case.output.strip() and 
                       judge0_response.status == 'Accepted',
                    status=judge0_response.status,
                    input=test_case.input,
                    stdout=judge0_response.stdout,
                    expected=test_case.output,
                    stderr=judge0_response.stderr,
                    time=judge0_response.time,
                    memory=judge0_response.memory
                )
                
                results.append(result)
                
            except Exception as e:
                logger.error(f"Test case execution error: {e}")
                error_result = create_error_test_result(
                    input=test_case.input,
                    expected=test_case.output,
                    error=str(e)
                )
                results.append(error_result)
        
        # Calculate summary
        passed = sum(1 for result in results if result.ok)
        total = len(results)
        
        summary = TestSummary(passed=passed, total=total)
        
        return TestExecutionResponse(summary=summary, results=results)
    
    def get_supported_languages(self) -> List[LanguageInfo]:
        """
        Get list of supported programming languages.
        
        Returns:
            List of LanguageInfo dataclasses
        """
        languages = []
        for name, lang_id in LANGUAGE_MAP.items():
            display_name = self._get_display_name(name)
            languages.append(LanguageInfo(
                name=name,
                id=lang_id,
                display_name=display_name
            ))
        
        return languages
    
    def _get_display_name(self, name: str) -> str:
        """Get human-readable display name for language."""
        display_names = {
            'python3': 'Python 3',
            'cpp': 'C++',
            'csharp': 'C#',
            'javascript': 'JavaScript',
            'node': 'Node.js',
        }
        return display_names.get(name, name.replace('_', ' ').title())
