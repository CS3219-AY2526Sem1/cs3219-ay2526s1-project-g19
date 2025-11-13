# PeerPrep Microservices - Code Migration Guide

## Overview

This guide details the **code changes required** in each service after updating Docker configurations for service discovery and nginx proxying.

---

## Table of Contents

1. [Breaking Changes Summary](#breaking-changes-summary)
2. [Backend Services Code Changes](#backend-services-code-changes)
3. [Frontend Code Changes](#frontend-code-changes)
4. [Testing Your Changes](#testing-your-changes)
5. [Troubleshooting](#troubleshooting)

---

## Breaking Changes Summary

### ✅ What Changed in Docker Configuration

| Component | Old | New | Impact |
|-----------|-----|-----|--------|
| Service Names | `user_service` | `user-service` | ✅ Handled by docker-compose |
| Collaboration Port | `8005` | `8000` | ⚠️ **CODE CHANGE REQUIRED** |
| Chat Port | `8006` | `8000` | ⚠️ **CODE CHANGE REQUIRED** |
| Frontend Access | `http://localhost:8001` | `http://localhost/user-service-api` | ⚠️ **CODE CHANGE REQUIRED** |
| Service Discovery | Manual | Environment variables | ⚠️ **CODE CHANGE REQUIRED** |

### ⚠️ Action Required

1. **Collaboration & Chat Services**: Update port from 8005/8006 → 8000
2. **All Services**: Add code to use service URL environment variables
3. **Frontend**: Already using proxy paths - **NO CHANGES NEEDED** if using env vars correctly

---

## Backend Services Code Changes

### 1. Collaboration Service - Port Change

**Current Issue**: Service hardcoded to listen on port 8005

#### File: `collaboration_service/server.js` (or `index.js`)

**BEFORE:**
```javascript
const express = require('express');
const app = express();

// Hardcoded port
const PORT = 8005;

app.listen(PORT, () => {
  console.log(`Collaboration service running on port ${PORT}`);
});
```

**AFTER:**
```javascript
const express = require('express');
const app = express();

// Read from environment variable, default to 8000
const PORT = process.env.PORT || 8000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Collaboration service running on port ${PORT}`);
});
```

**Why?**
- Docker now maps `8005:8000` (external:internal)
- Application must listen on port 8000 internally
- Environment variable allows flexibility

---

### 2. Chat Service - Port Change

**Current Issue**: Service hardcoded to listen on port 8006

#### File: `chat_service/server.js` (or `index.js`)

**BEFORE:**
```javascript
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

// Hardcoded port
const PORT = 8006;

server.listen(PORT, () => {
  console.log(`Chat service running on port ${PORT}`);
});
```

**AFTER:**
```javascript
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

// Read from environment variable, default to 8000
const PORT = process.env.PORT || 8000;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Chat service running on port ${PORT}`);
});
```

---

### 3. Service-to-Service Communication (All Services)

**Use Case**: When a backend service needs to call another service

#### Example: User Service calling Question Service

**File: `user_service/services/question_client.py`** (Django example)

**BEFORE:**
```python
import requests

def get_questions_for_user(user_id):
    # Hardcoded URL - won't work in Docker or ECS
    url = "http://localhost:8001/api/questions"
    response = requests.get(url, params={"user_id": user_id})
    return response.json()
```

**AFTER:**
```python
import requests
from django.conf import settings

def get_questions_for_user(user_id):
    # Use service discovery URL from environment
    base_url = settings.QUESTION_SERVICE_URL
    url = f"{base_url}/api/questions"

    try:
        response = requests.get(url, params={"user_id": user_id}, timeout=10)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as e:
        # Handle service communication errors
        logger.error(f"Failed to fetch questions: {e}")
        raise
```

**File: `user_service/user_service/settings.py`**

Add service URL configuration:

```python
# Service-to-Service Communication URLs
QUESTION_SERVICE_URL = os.environ.get('QUESTION_SERVICE_URL', 'http://question-service:8000')
MATCHING_SERVICE_URL = os.environ.get('MATCHING_SERVICE_URL', 'http://matching-service:8000')
HISTORY_SERVICE_URL = os.environ.get('HISTORY_SERVICE_URL', 'http://history-service:8000')
COLLABORATION_SERVICE_URL = os.environ.get('COLLABORATION_SERVICE_URL', 'http://collaboration-service:8000')
CHAT_SERVICE_URL = os.environ.get('CHAT_SERVICE_URL', 'http://chat-service:8000')
```

---

#### Example: Matching Service (Node.js) calling User Service

**File: `matching_service/services/userClient.js`**

**BEFORE:**
```javascript
const axios = require('axios');

async function getUserProfile(userId) {
  // Hardcoded URL
  const response = await axios.get(`http://localhost:8004/api/users/${userId}`);
  return response.data;
}

module.exports = { getUserProfile };
```

**AFTER:**
```javascript
const axios = require('axios');

// Read from environment variable
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://user-service:8000';

async function getUserProfile(userId) {
  try {
    const url = `${USER_SERVICE_URL}/api/users/${userId}`;
    const response = await axios.get(url, { timeout: 10000 });
    return response.data;
  } catch (error) {
    console.error(`Failed to fetch user ${userId}:`, error.message);
    throw new Error('User service unavailable');
  }
}

module.exports = { getUserProfile };
```

**File: `matching_service/config/services.js`** (optional - centralized config)

```javascript
module.exports = {
  USER_SERVICE_URL: process.env.USER_SERVICE_URL || 'http://user-service:8000',
  QUESTION_SERVICE_URL: process.env.QUESTION_SERVICE_URL || 'http://question-service:8000',
  HISTORY_SERVICE_URL: process.env.HISTORY_SERVICE_URL || 'http://history-service:8000',
};
```

---

### 4. ALLOWED_HOSTS Configuration (Django Services)

**Issue**: Django services need to accept requests from their service name

#### All Django Services: `*/settings.py`

**BEFORE:**
```python
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1').split(',')
```

**AFTER:**
```python
# Service name is now hyphenated
ALLOWED_HOSTS = os.environ.get(
    'ALLOWED_HOSTS',
    'localhost,127.0.0.1,user-service,question-service,history-service'
).split(',')
```

**Already handled in docker-compose**, but verify your settings.py respects the environment variable.

---

## Frontend Code Changes

### ✅ Good News: Likely NO CHANGES NEEDED!

If your frontend code already uses environment variables, **you're done**.

### Verify Your Frontend Code

#### File: `frontend/src/config/api.ts` (or similar)

**✅ CORRECT (No changes needed):**
```typescript
export const API_ENDPOINTS = {
  USER_SERVICE: import.meta.env.VITE_USER_SERVICE_URL,
  QUESTION_SERVICE: import.meta.env.VITE_QUESTION_SERVICE_URL,
  MATCHING_SERVICE: import.meta.env.VITE_MATCHING_SERVICE_URL,
  HISTORY_SERVICE: import.meta.env.VITE_HISTORY_SERVICE_URL,
  COLLABORATION_SERVICE: import.meta.env.VITE_COLLABORATION_SERVICE_URL,
  CHAT_SERVICE: import.meta.env.VITE_CHAT_SERVICE_URL,
} as const;
```

**Usage:**
```typescript
import { API_ENDPOINTS } from '@/config/api';

async function login(email: string, password: string) {
  // This will automatically use /user-service-api from env vars
  const response = await fetch(`${API_ENDPOINTS.USER_SERVICE}/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  return response.json();
}
```

**How it works:**
- `.env` sets `VITE_USER_SERVICE_URL=/user-service-api`
- Frontend calls `/user-service-api/login`
- Nginx strips prefix, forwards to `user-service:8000/login`

---

**❌ INCORRECT (Needs fixing):**
```typescript
// Hardcoded URLs - MUST BE REMOVED
export const API_ENDPOINTS = {
  USER_SERVICE: 'http://localhost:8004',  // ❌ BAD
  QUESTION_SERVICE: 'http://localhost:8001',  // ❌ BAD
};
```

**Fix:**
```typescript
export const API_ENDPOINTS = {
  USER_SERVICE: import.meta.env.VITE_USER_SERVICE_URL || '/user-service-api',
  QUESTION_SERVICE: import.meta.env.VITE_QUESTION_SERVICE_URL || '/question-service-api',
};
```

---

### WebSocket Connections (Chat/Collaboration)

**File: `frontend/src/services/chatSocket.ts`**

**BEFORE:**
```typescript
import io from 'socket.io-client';

// Hardcoded URL
const socket = io('http://localhost:8006');
```

**AFTER:**
```typescript
import io from 'socket.io-client';

// Use environment variable - works with nginx proxy
const CHAT_SERVICE_URL = import.meta.env.VITE_CHAT_SERVICE_URL || '/chat-service-api';

// For WebSocket, construct full URL
const socket = io(CHAT_SERVICE_URL, {
  path: '/socket.io',  // Default socket.io path
  transports: ['websocket', 'polling'],
});
```

**OR** if your backend uses a custom path:

```typescript
const socket = io('/', {  // Same origin (nginx will proxy)
  path: '/chat-service-api/socket.io',
  transports: ['websocket', 'polling'],
});
```

---

## Testing Your Changes

### Step 1: Test Service Port Changes

```bash
# Rebuild services with port changes
docker-compose up --build collaboration-service chat-service

# Verify they're listening on port 8000
docker exec -it peerprep_collaboration_service curl http://localhost:8000/health
docker exec -it peerprep_chat_service curl http://localhost:8000/health

# Should return 200 OK
```

### Step 2: Test Service Discovery

```bash
# From user service, call question service
docker exec -it peerprep_user_service curl http://question-service:8000/health

# From question service, call user service
docker exec -it peerprep_question_service curl http://user-service:8000/health

# All should return 200 OK
```

### Step 3: Test Nginx Proxy

```bash
# Start all services including frontend (nginx)
docker-compose up --build

# Test nginx proxy routing
curl http://localhost/user-service-api/health
curl http://localhost/question-service-api/health
curl http://localhost/matching-service-api/health

# All should return service responses
```

### Step 4: Test Frontend Integration

```bash
# Access frontend
open http://localhost

# Open browser console, verify API calls:
# Network tab should show:
#   /user-service-api/login → 200 OK
#   /question-service-api/questions → 200 OK
# NOT:
#   http://localhost:8001/... → CORS error (old pattern)
```

### Step 5: Test WebSocket Connections

```javascript
// Browser console
const socket = io('/chat-service-api');
socket.on('connect', () => console.log('Connected!'));

// Should see "Connected!" without errors
```

---

## Troubleshooting

### Issue 1: "Connection Refused" when services call each other

**Symptom:**
```
requests.exceptions.ConnectionError: HTTPConnectionPool(host='question-service', port=8000)
```

**Diagnosis:**
```bash
# Check if service name resolves
docker exec -it peerprep_user_service ping question-service

# Check if service is running
docker ps | grep question
```

**Fix:**
- Ensure all services are on `peerprep_shared_network`
- Verify service names are hyphenated in docker-compose.yml
- Restart services: `docker-compose down && docker-compose up`

---

### Issue 2: Nginx 502 Bad Gateway

**Symptom:**
Browser shows nginx 502 error when accessing `/user-service-api/`

**Diagnosis:**
```bash
# Check nginx logs
docker logs peerprep_frontend

# Verify nginx config was generated correctly
docker exec -it peerprep_frontend cat /etc/nginx/conf.d/default.conf

# Should see:
# proxy_pass http://user-service:8000;
# NOT:
# proxy_pass http://${NGINX_USER_SERVICE_HOST}:8000;  (envsubst didn't run)
```

**Fix:**
```bash
# Check environment variables are set
docker exec -it peerprep_frontend env | grep NGINX

# Rebuild frontend
docker-compose up --build frontend
```

---

### Issue 3: Collaboration/Chat service won't start

**Symptom:**
```
Error: listen EADDRINUSE: address already in use :::8005
```

**Diagnosis:**
Your application code is still hardcoded to port 8005/8006

**Fix:**
Update your code to use `process.env.PORT || 8000` (see Section 2 above)

---

### Issue 4: Frontend can't reach APIs

**Symptom:**
Browser console: `GET http://localhost/user-service-api/login 404 Not Found`

**Diagnosis:**
Check if frontend is using nginx (production stage) or vite dev server (development stage)

```bash
# Check which stage is running
docker ps | grep frontend

# If using vite dev server, APIs won't be proxied
```

**Fix:**
```bash
# Ensure frontend uses production (nginx) stage
FRONTEND_BUILD_STAGE=production docker-compose up frontend

# OR verify .env has:
# FRONTEND_BUILD_STAGE=production (not set in our config, defaults to production)
```

---

### Issue 5: WebSocket connection fails

**Symptom:**
Browser console: `WebSocket connection to 'ws://localhost/chat-service-api/socket.io' failed`

**Diagnosis:**
Nginx not configured for WebSocket upgrade

**Fix:**
Verify nginx.conf.template has WebSocket headers (already included in our config):
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

---

## Code Change Checklist

Before deploying, verify:

### Backend Services
- [ ] Collaboration service listens on port 8000 (not 8005)
- [ ] Chat service listens on port 8000 (not 8006)
- [ ] All services use `process.env.PORT` or equivalent
- [ ] Service-to-service calls use environment variables (not localhost:PORT)
- [ ] Django services have correct ALLOWED_HOSTS

### Frontend
- [ ] API endpoints use environment variables (VITE_*_SERVICE_URL)
- [ ] No hardcoded localhost:PORT URLs
- [ ] WebSocket connections use proxy paths

### Testing
- [ ] Services can ping each other by name (question-service, user-service, etc.)
- [ ] Nginx proxy routes work (curl http://localhost/user-service-api/health)
- [ ] Frontend loads and makes API calls through nginx
- [ ] WebSocket connections establish successfully

---

## Next Steps After Code Changes

1. **Local Testing**
   ```bash
   docker-compose down
   docker-compose up --build
   ```

2. **Integration Testing**
   - Test all user flows end-to-end
   - Verify service-to-service communication
   - Check WebSocket features

3. **Production Deployment**
   - Update ECS task definitions with `.env.prod` values
   - Configure ECS service discovery namespace
   - Deploy and monitor logs

---

## Summary of Required Code Changes

| Service | Files to Change | Change Type |
|---------|----------------|-------------|
| collaboration_service | `server.js` / `index.js` | Port 8005 → 8000 |
| chat_service | `server.js` / `index.js` | Port 8006 → 8000 |
| user_service | `settings.py`, service clients | Add service URLs |
| question_service | `settings.py`, service clients | Add service URLs |
| matching_service | Config files, service clients | Add service URLs |
| history_service | `settings.py`, service clients | Add service URLs |
| frontend | `config/api.ts`, socket clients | Verify env var usage |

**Estimated effort**: 1-2 hours for backend changes, 30 minutes for frontend verification

---

**Document Version:** 1.0
**Last Updated:** 2025-10-08
**Status:** Ready for Implementation
