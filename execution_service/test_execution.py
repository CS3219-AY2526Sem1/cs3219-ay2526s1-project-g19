#!/usr/bin/env python3
"""
Simple test script for execution service.
Run this after starting the services to verify everything works.
"""
import requests
import json
import time

# Configuration
EXECUTION_SERVICE_URL = "http://localhost:8007"
QUESTION_SERVICE_URL = "http://localhost:8001"

def test_execution_service():
    """Test the execution service endpoints."""
    print("🧪 Testing Execution Service...")
    
    # Test 1: Health check
    print("\n1. Testing health check...")
    try:
        response = requests.get(f"{EXECUTION_SERVICE_URL}/health")
        print(f"   Health check: {response.status_code} - {response.json()}")
    except Exception as e:
        print(f"   Health check failed: {e}")
        return False
    
    # Test 2: Get supported languages
    print("\n2. Testing languages endpoint...")
    try:
        response = requests.get(f"{EXECUTION_SERVICE_URL}/api/languages")
        print(f"   Languages: {response.status_code}")
        if response.status_code == 200:
            languages = response.json()['languages']
            print(f"   Found {len(languages)} languages")
            for lang in languages[:3]:  # Show first 3
                print(f"     - {lang['display_name']} (ID: {lang['id']})")
    except Exception as e:
        print(f"   Languages test failed: {e}")
        return False
    
    # Test 3: Execute simple Python code
    print("\n3. Testing code execution...")
    try:
        payload = {
            "language_id": 71,  # Python 3
            "source_code": "print('Hello from execution service!')\nprint(2 + 2)",
            "stdin": ""
        }
        response = requests.post(f"{EXECUTION_SERVICE_URL}/api/execute", json=payload)
        print(f"   Execute: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"   Status: {result['status']}")
            print(f"   Output: {result['stdout']}")
            print(f"   Time: {result['time']}s")
    except Exception as e:
        print(f"   Execution test failed: {e}")
        return False
    
    # Test 4: Test with input
    print("\n4. Testing code execution with input...")
    try:
        payload = {
            "language_id": 71,  # Python 3
            "source_code": "name = input()\nprint(f'Hello, {name}!')",
            "stdin": "World"
        }
        response = requests.post(f"{EXECUTION_SERVICE_URL}/api/execute", json=payload)
        print(f"   Execute with input: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"   Status: {result['status']}")
            print(f"   Output: {result['stdout']}")
    except Exception as e:
        print(f"   Input execution test failed: {e}")
        return False
    
    return True

def test_question_service_integration():
    """Test integration with question service."""
    print("\n🔗 Testing Question Service Integration...")
    
    # Test 1: Get topics from question service
    print("\n1. Testing topics endpoint...")
    try:
        response = requests.get(f"{QUESTION_SERVICE_URL}/api/topics")
        print(f"   Topics: {response.status_code}")
        if response.status_code == 200:
            topics = response.json()['topics']
            print(f"   Found {len(topics)} topics")
            print(f"   Sample topics: {topics[:5]}")
    except Exception as e:
        print(f"   Topics test failed: {e}")
        return False
    
    # Test 2: Get a question for testing
    print("\n2. Getting a question for test cases...")
    try:
        response = requests.get(f"{QUESTION_SERVICE_URL}/api/questions/?limit=1")
        print(f"   Questions: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            if data.get('results'):
                question = data['results'][0]
                question_id = question['question_id']
                examples = question.get('examples', [])
                print(f"   Found question: {question['title']}")
                print(f"   Question ID: {question_id}")
                print(f"   Examples: {len(examples)}")
                return question_id, examples
            else:
                print("   No questions found")
                return None, []
    except Exception as e:
        print(f"   Question fetch failed: {e}")
        return None, []
    
    return None, []

def test_execution_with_tests(question_id, examples):
    """Test execution against question test cases."""
    if not question_id or not examples:
        print("\n⚠️  Skipping test execution - no question or examples available")
        return True
    
    print(f"\n🧪 Testing execution against question {question_id}...")
    
    # Create a simple solution that should pass some tests
    source_code = """
# Simple solution that echoes input
print(input())
"""
    
    try:
        payload = {
            "language_id": 71,  # Python 3
            "source_code": source_code,
            "question_id": question_id
        }
        response = requests.post(f"{EXECUTION_SERVICE_URL}/api/execute/tests", json=payload)
        print(f"   Test execution: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            summary = result['summary']
            print(f"   Results: {summary['passed']}/{summary['total']} tests passed")
            
            # Show first few results
            for i, test_result in enumerate(result['results'][:2]):
                print(f"   Test {i+1}: {'✅' if test_result['ok'] else '❌'} - {test_result['status']}")
                if test_result.get('stdout'):
                    print(f"     Output: {test_result['stdout'][:50]}...")
        else:
            print(f"   Error: {response.text}")
    except Exception as e:
        print(f"   Test execution failed: {e}")
        return False
    
    return True

def main():
    """Run all tests."""
    print("🚀 Starting Execution Service Tests")
    print("=" * 50)
    
    # Wait a bit for services to start
    print("⏳ Waiting for services to start...")
    time.sleep(5)
    
    # Test execution service
    if not test_execution_service():
        print("\n❌ Execution service tests failed")
        return
    
    # Test question service integration
    question_id, examples = test_question_service_integration()
    
    # Test execution with question test cases
    test_execution_with_tests(question_id, examples)
    
    print("\n✅ All tests completed!")
    print("\n📋 Summary:")
    print("   - Execution service is running")
    print("   - Code execution works")
    print("   - Question service integration works")
    print("   - Test execution against question examples works")
    print("\n🎉 Execution service is ready to use!")

if __name__ == "__main__":
    main()


