# Execution Service

A Django-based microservice for code execution and testing, integrated with Judge0 cloud and the question service.

## Features

- **Code Execution**: Execute code in multiple programming languages using Judge0
- **Test Execution**: Run code against official test cases from the question service
- **Language Support**: Support for Python, JavaScript, Java, C++, and more
- **RESTful API**: Clean REST API with OpenAPI documentation

## Architecture

```
Frontend (Collaboration Page)
    ↓
Execution Service (Django)
    ↓
Judge0 (Code Execution Engine)
    ↓
Question Service (Test Cases)
```

## API Endpoints

### Execute Code
```http
POST /api/execute
Content-Type: application/json

{
  "language_id": 71,
  "source_code": "print('Hello, World!')",
  "stdin": "optional input"
}
```

### Execute Against Test Cases
```http
POST /api/execute/tests
Content-Type: application/json

{
  "language_id": 71,
  "source_code": "print(input())",
  "question_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### Get Supported Languages
```http
GET /api/languages
```

## Supported Languages

| Language | Judge0 ID | Display Name |
|----------|-----------|--------------|
| Python 3 | 71 | Python 3 |
| JavaScript | 63 | JavaScript |
| Java | 62 | Java |
| C++ | 54 | C++ |
| C | 50 | C |
| C# | 51 | C# |
| Go | 60 | Go |
| Rust | 73 | Rust |
| PHP | 68 | PHP |
| Ruby | 72 | Ruby |
| Swift | 83 | Swift |
| Kotlin | 78 | Kotlin |
| Scala | 81 | Scala |
| TypeScript | 74 | TypeScript |

## Quick Start

### Using Docker Compose (Recommended)

1. **Start all services**:
   ```bash
   cd /path/to/project
   docker-compose up
   ```

2. **Test the service**:
   ```bash
   cd execution_service
   python test_execution.py
   ```

### Standalone Development

1. **Start Judge0**:
   ```bash
   docker run -p 2358:2358 judge0/judge0:latest
   ```

2. **Start Execution Service**:
   ```bash
   cd execution_service
   pip install -r requirements.txt
   python manage.py runserver 0.0.0.0:8006
   ```

3. **Start Question Service** (for test cases):
   ```bash
   cd question_service
   docker-compose up
   ```

## Configuration

Environment variables:

- `JUDGE0_URL`: Judge0 service URL (default: `http://judge0:2358`)
- `QUESTION_SERVICE_URL`: Question service URL (default: `http://question-service:8000`)
- `DEBUG`: Enable debug mode (default: `true`)
- `SECRET_KEY`: Django secret key
- `ALLOWED_HOSTS`: Comma-separated list of allowed hosts

## Integration with Frontend

### Run Button (Single Execution)
```javascript
const executeCode = async (code, language, input = '') => {
  const response = await fetch('/execution-service-api/api/execute', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      language_id: getLanguageId(language),
      source_code: code,
      stdin: input
    })
  });
  
  const result = await response.json();
  return result;
};
```

### Run Tests Button (Against Question Examples)
```javascript
const runTests = async (code, language, questionId) => {
  const response = await fetch('/execution-service-api/api/execute/tests', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      language_id: getLanguageId(language),
      source_code: code,
      question_id: questionId
    })
  });
  
  const result = await response.json();
  return result;
};
```

## Response Format

### Single Execution Response
```json
{
  "status": "Accepted",
  "stdout": "Hello, World!\n",
  "stderr": "",
  "time": "0.05",
  "memory": 12345,
  "compile_output": ""
}
```

### Test Execution Response
```json
{
  "summary": {
    "passed": 2,
    "total": 3
  },
  "results": [
    {
      "ok": true,
      "status": "Accepted",
      "stdout": "expected output",
      "expected": "expected output",
      "stderr": "",
      "time": "0.05",
      "memory": 12345
    }
  ]
}
```

## Error Handling

The service handles various error conditions:

- **400 Bad Request**: Missing required parameters
- **502 Bad Gateway**: Judge0 service unavailable or execution failed
- **500 Internal Server Error**: Unexpected server errors

## Security Considerations

- Code execution is sandboxed by Judge0
- No persistent storage of user code
- Rate limiting should be implemented in production
- Input validation and sanitization

## Development

### Project Structure
```
execution_service/
├── execution_service/
│   ├── apps/
│   │   ├── views.py          # API views
│   │   └── urls.py           # URL routing
│   ├── middleware.py         # Proxy middleware
│   ├── settings.py           # Django settings
│   └── urls.py               # Main URL config
├── docker-compose.yml        # Service orchestration
├── Dockerfile               # Container definition
├── requirements.txt         # Python dependencies
├── test_execution.py        # Test script
└── README.md               # This file
```

### Adding New Languages

1. Add language mapping to `LANGUAGE_MAP` in `views.py`
2. Ensure Judge0 supports the language
3. Update the languages endpoint if needed

### Testing

Run the test script to verify functionality:
```bash
python test_execution.py
```

## Troubleshooting

### Common Issues

1. **Judge0 not responding**: Check if Judge0 container is running
2. **Question service unavailable**: Ensure question service is running
3. **Execution timeouts**: Check Judge0 configuration and resource limits

### Logs

Check service logs:
```bash
docker-compose logs execution-service
docker-compose logs judge0
```

## Production Deployment

1. Set `DEBUG=False` in production
2. Use a proper secret key
3. Configure proper CORS settings
4. Set up monitoring and logging
5. Consider rate limiting and authentication
