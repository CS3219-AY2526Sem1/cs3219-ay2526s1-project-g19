"""
Serializers for execution service API endpoints.
"""
from dataclasses import dataclass
from typing import List, Optional, Dict, Any
from rest_framework import serializers


@dataclass
class Judge0Submission:
    """Judge0 submission request data."""
    language_id: int
    source_code: str
    stdin: str = ""


@dataclass
class Judge0Response:
    """Judge0 execution response data."""
    status: str
    stdout: str
    stderr: str
    time: str
    memory: int
    compile_output: str = ""


@dataclass
class TestCase:
    """Test case data from question service."""
    input: str
    output: str


@dataclass
class TestResult:
    """Result of a single test case execution."""
    ok: bool
    status: str
    input: str
    stdout: str
    expected: str
    stderr: str
    time: str
    memory: int
    error: Optional[str] = None


@dataclass
class TestSummary:
    """Summary of test execution results."""
    passed: int
    total: int


@dataclass
class TestExecutionResponse:
    """Complete test execution response."""
    summary: TestSummary
    results: List[TestResult]


@dataclass
class LanguageInfo:
    """Programming language information."""
    name: str
    id: int
    display_name: str


# DRF Serializers
class ExecuteRequestSerializer(serializers.Serializer):
    """Serializer for code execution requests."""
    language_id = serializers.IntegerField(
        help_text="Judge0 language ID (e.g., 71 for Python 3)"
    )
    source_code = serializers.CharField(
        help_text="Source code to execute"
    )
    stdin = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        default="",
        help_text="Standard input for the program"
    )


class ExecuteResponseSerializer(serializers.Serializer):
    """Serializer for code execution responses."""
    status = serializers.CharField(help_text="Execution status")
    stdout = serializers.CharField(help_text="Standard output")
    stderr = serializers.CharField(allow_blank=True, allow_null=True, help_text="Standard error")
    time = serializers.CharField(allow_blank=True, help_text="Execution time")
    memory = serializers.IntegerField(help_text="Memory usage")
    compile_output = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        help_text="Compilation output"
    )


class ExecuteTestsRequestSerializer(serializers.Serializer):
    """Serializer for test execution requests."""
    language_id = serializers.IntegerField(
        help_text="Judge0 language ID"
    )
    source_code = serializers.CharField(
        help_text="Source code to execute"
    )
    question_id = serializers.UUIDField(
        help_text="Question ID to fetch test cases from"
    )


class TestResultSerializer(serializers.Serializer):
    """Serializer for individual test results."""
    ok = serializers.BooleanField(help_text="Whether test passed")
    status = serializers.CharField(help_text="Execution status")
    input = serializers.CharField(allow_blank=True, help_text="Test input")
    stdout = serializers.CharField(allow_blank=True, help_text="Program output")
    expected = serializers.CharField(allow_blank=True, help_text="Expected output")
    stderr = serializers.CharField(allow_blank=True, allow_null=True, help_text="Error output")
    time = serializers.CharField(allow_blank=True, help_text="Execution time")
    memory = serializers.IntegerField(help_text="Memory usage")
    error = serializers.CharField(
        required=False,
        allow_null=True,
        allow_blank=True,
        help_text="Error message if execution failed"
    )


class TestSummarySerializer(serializers.Serializer):
    """Serializer for test execution summary."""
    passed = serializers.IntegerField(help_text="Number of tests passed")
    total = serializers.IntegerField(help_text="Total number of tests")


class TestExecutionResponseSerializer(serializers.Serializer):
    """Serializer for complete test execution response."""
    summary = TestSummarySerializer(help_text="Test execution summary")
    results = TestResultSerializer(many=True, help_text="Individual test results")


class LanguageInfoSerializer(serializers.Serializer):
    """Serializer for programming language information."""
    name = serializers.CharField(help_text="Language identifier")
    id = serializers.IntegerField(help_text="Judge0 language ID")
    display_name = serializers.CharField(help_text="Human-readable language name")


class LanguagesResponseSerializer(serializers.Serializer):
    """Serializer for languages list response."""
    languages = LanguageInfoSerializer(many=True, help_text="Supported languages")


# Utility functions for data conversion
def judge0_response_to_dataclass(data: Dict[str, Any]) -> Judge0Response:
    """Convert Judge0 API response to dataclass."""
    return Judge0Response(
        status=data.get('status', {}).get('description', 'Unknown'),
        stdout=data.get('stdout') or '',
        stderr=data.get('stderr') or '',
        time=data.get('time') or '',
        memory=data.get('memory', 0),
        compile_output=data.get('compile_output') or ''
    )


def test_case_to_dataclass(data: Dict[str, Any]) -> TestCase:
    """Convert test case data to dataclass."""
    return TestCase(
        input=data.get('input', ''),
        output=data.get('output', '')
    )


def create_test_result(
    ok: bool,
    status: str,
    input: str,
    stdout: str,
    expected: str,
    stderr: str,
    time: str,
    memory: int,
    error: Optional[str] = None
) -> TestResult:
    """Create a TestResult dataclass."""
    return TestResult(
        ok=ok,
        status=status,
        input=input,
        stdout=stdout,
        expected=expected,
        stderr=stderr,
        time=time,
        memory=memory,
        error=error
    )


def create_error_test_result(
    input: str,
    expected: str,
    error: str
) -> TestResult:
    """Create an error TestResult dataclass."""
    return TestResult(
        ok=False,
        status='Error',
        input=input,
        stdout='',
        expected=expected,
        stderr=error,
        time='0',
        memory=0,
        error='exec_failed'
    )
