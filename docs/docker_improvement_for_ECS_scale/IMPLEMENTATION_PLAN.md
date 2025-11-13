# PeerPrep Microservices - Service Discovery & Nginx Implementation Plan

## Executive Summary

This document outlines the comprehensive plan to enable:
1. **Backend-to-backend communication** using service names (e.g., `http://user-service:8000`)
2. **Frontend Nginx proxying** for browser requests (`/user-service-api/*` → `http://user-service:8000/*`)
3. **Environment parity** between local Docker development and AWS ECS production

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Architecture Goals](#architecture-goals)
3. [Implementation Phases](#implementation-phases)
4. [Detailed Changes](#detailed-changes)
5. [Configuration Files](#configuration-files)
6. [Migration Guide](#migration-guide)
7. [Testing Strategy](#testing-strategy)

---

## Current State Analysis

### Service Naming Inconsistencies

| Service | Current Name | Target Name | Status |
|---------|-------------|-------------|--------|
| User | `user_service` | `user-service` | ❌ Needs change |
| Question | `question_service` | `question-service` | ❌ Needs change |
| Matching | `matching_service` | `matching-service` | ❌ Needs change |
| History | `history_service` | `history-service` | ❌ Needs change |
| Collaboration | `collaboration_service` | `collaboration-service` | ❌ Needs change |
| Chat | `chat_service` | `chat-service` | ❌ Needs change |

**Why hyphenated?**
- DNS-compliant (underscores not recommended in hostnames)
- ECS service discovery convention
- Industry standard for microservices

### Port Configuration Issues

| Service | Current Internal Port | Target Internal Port | Fix Required |
|---------|---------------------|---------------------|--------------|
| Question | 8000 | 8000 | ✅ OK |
| Matching | 8000 | 8000 | ✅ OK |
| History | 8000 | 8000 | ✅ OK |
| User | 8000 | 8000 | ✅ OK |
| Collaboration | **8005** | 8000 | ❌ **MUST FIX** |
| Chat | **8006** | 8000 | ❌ **MUST FIX** |

**Why port 8000 for all?**
- Simplifies service discovery configuration
- ECS target groups can use consistent health check paths
- Environment variable substitution becomes trivial
- External ports can still differ (mapped in docker-compose)

### Current Network Architecture

```
┌─────────────────────────────────────────────────────────┐
│         peerprep_shared_network (external)              │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐            │
│  │ Frontend │  │  User    │  │ Question │  ...       │
│  │          │  │ Service  │  │ Service  │            │
│  └──────────┘  └──────────┘  └──────────┘            │
│                      │              │                  │
└──────────────────────┼──────────────┼─────────────────┘
                       │              │
              ┌────────┴───┐   ┌──────┴───────┐
              │ user_      │   │ question_    │
              │ network    │   │ network      │
              │  (private) │   │  (private)   │
              │            │   │              │
              │  user_db   │   │ question_db  │
              └────────────┘   └──────────────┘
```

### Missing Components

❌ **Frontend has no nginx configuration**
- Currently running Vite dev server only
- No production build setup
- No API proxying

❌ **No service-to-service communication URLs**
- Services cannot call each other
- No environment variables for inter-service URLs

❌ **No production environment file**
- `.env.prod` doesn't exist
- No ECS service discovery configuration

---

## Architecture Goals

### Local Development (Docker Compose)

```
┌──────────────────────────────────────────────────────────────┐
│                    Developer's Browser                        │
└───────┬──────────────────────────────────────────────────────┘
        │
        ├─ http://localhost:5173  ────────────┐
        │                                      │
        └─ http://localhost:8001/api/...  ────┼─── Direct Access
                                               │   (Dev convenience)
┌──────────────────────────────────────────────┼───────────────┐
│              Docker: peerprep_shared_network │               │
│                                              ▼               │
│  ┌────────────────┐                   ┌──────────┐          │
│  │   Frontend     │                   │  Question│          │
│  │   (Vite)       │                   │  Service │          │
│  │   :5173        │                   │  :8000   │          │
│  └────────────────┘                   └──────────┘          │
│         │                                                    │
│         │ Backend-to-Backend:                               │
│         │ http://question-service:8000                      │
│         └──────────────────────────────────────────▶        │
└───────────────────────────────────────────────────────────────┘
```

### Production (AWS ECS)

```
┌──────────────────────────────────────────────────────────────┐
│                    User's Browser                             │
└───────┬──────────────────────────────────────────────────────┘
        │
        │ https://peerprep.com/user-service-api/login
        │
┌───────▼──────────────────────────────────────────────────────┐
│                Application Load Balancer                      │
└───────┬──────────────────────────────────────────────────────┘
        │
┌───────▼──────────────────────────────────────────────────────┐
│                    ECS Cluster                                │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Frontend Task (Nginx)                                   │ │
│  │                                                         │ │
│  │  Location: /user-service-api/                          │ │
│  │  Proxy to: http://user-service.peerprep-prod.internal  │ │
│  └────────────┬────────────────────────────────────────────┘ │
│               │                                              │
│               │ ECS Service Discovery DNS:                  │
│               │ user-service.peerprep-prod.internal:8000    │
│               │                                              │
│  ┌────────────▼────────────────────────────────────────────┐ │
│  │ User Service Task                                       │ │
│  │ Port: 8000                                              │ │
│  └─────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Service Naming Standardization ⚙️

**Goal:** Rename all services to hyphenated format for DNS compliance

**Files to Update:**
- `/user_service/docker-compose.yml`
- `/question_service/docker-compose.yml`
- `/matching_service/docker-compose.yml`
- `/history_service/docker-compose.yml`
- `/collaboration_service/docker-compose.yml`
- `/chat_service/docker-compose.yml`

**Changes Required:**
1. Service names: `user_service` → `user-service`
2. Container names: `peerprep_user_service` → `peerprep_user_service` (keep underscores)
3. Database hostnames: Keep as-is (e.g., `user_db`, `question_db`)
4. Redis hostnames: Keep as-is (e.g., `matching_redis`)
5. Network names: Keep as-is (private networks unaffected)

**Impact:**
- ✅ Services discoverable via `http://user-service:8000`
- ✅ Works in both Docker and ECS
- ⚠️ Existing code using service names must be updated

---

### Phase 2: Port Standardization ⚙️

**Goal:** All backend services expose port 8000 internally

**Services Requiring Changes:**

#### Collaboration Service
```yaml
# BEFORE
ports:
  - "${COLLABORATION_SERVICE_PORT:-8005}:8005"
environment:
  - PORT=8005

# AFTER
ports:
  - "${COLLABORATION_SERVICE_PORT:-8005}:8000"
environment:
  - PORT=8000
```

#### Chat Service
```yaml
# BEFORE
ports:
  - "${CHAT_SERVICE_PORT:-8006}:8006"
environment:
  - PORT=8006

# AFTER
ports:
  - "${CHAT_SERVICE_PORT:-8006}:8000"
environment:
  - PORT=8000
```

**Impact:**
- ✅ Consistent internal port across all services
- ⚠️ Application code in collaboration/chat services must listen on port 8000
- ✅ External port mapping unchanged (still 8005, 8006 for dev)

---

### Phase 3: Environment Variables 🔧

#### `.env` (Local Development)

Add new section for **backend-to-backend communication**:

```bash
# -----------------------------------------------------------------------------
# Service-to-Service Communication (Backend Internal URLs)
# -----------------------------------------------------------------------------
# These URLs are used when backend services need to call each other
# In Docker: use service names (Docker DNS resolution)
# In ECS: use service discovery DNS

# Development (Docker Compose)
USER_SERVICE_URL=http://user-service:8000
QUESTION_SERVICE_URL=http://question-service:8000
MATCHING_SERVICE_URL=http://matching-service:8000
HISTORY_SERVICE_URL=http://history-service:8000
COLLABORATION_SERVICE_URL=http://collaboration-service:8000
CHAT_SERVICE_URL=http://chat-service:8000
```

Update existing database/redis hostnames:
```bash
# From:
MATCHING_REDIS_HOST=matching_redis
# To:
MATCHING_REDIS_HOST=matching-redis  # (if we want consistency, optional)
```

#### `.env.prod` (Production/ECS) - **NEW FILE**

```bash
# =============================================================================
# PeerPrep Microservices - Production Environment (AWS ECS)
# =============================================================================

# -----------------------------------------------------------------------------
# Environment Type
# -----------------------------------------------------------------------------
ENVIRONMENT=production

# -----------------------------------------------------------------------------
# Service Ports (Production - Internal to ECS tasks)
# -----------------------------------------------------------------------------
# All services expose port 8000 internally
FRONTEND_PORT=80
QUESTION_SERVICE_PORT=8000
MATCHING_SERVICE_PORT=8000
HISTORY_SERVICE_PORT=8000
USER_SERVICE_PORT=8000
COLLABORATION_SERVICE_PORT=8000
CHAT_SERVICE_PORT=8000

# -----------------------------------------------------------------------------
# Service-to-Service Communication (ECS Service Discovery)
# -----------------------------------------------------------------------------
# Format: http://<service-name>.<namespace>.internal:8000
# Namespace: peerprep-prod (defined in ECS service discovery)

USER_SERVICE_URL=http://user-service.peerprep-prod.internal:8000
QUESTION_SERVICE_URL=http://question-service.peerprep-prod.internal:8000
MATCHING_SERVICE_URL=http://matching-service.peerprep-prod.internal:8000
HISTORY_SERVICE_URL=http://history-service.peerprep-prod.internal:8000
COLLABORATION_SERVICE_URL=http://collaboration-service.peerprep-prod.internal:8000
CHAT_SERVICE_URL=http://chat-service.peerprep-prod.internal:8000

# -----------------------------------------------------------------------------
# Frontend Nginx Proxy Targets (Used in nginx.conf.template)
# -----------------------------------------------------------------------------
# These are substituted via envsubst when container starts
NGINX_USER_SERVICE_HOST=user-service.peerprep-prod.internal
NGINX_QUESTION_SERVICE_HOST=question-service.peerprep-prod.internal
NGINX_MATCHING_SERVICE_HOST=matching-service.peerprep-prod.internal
NGINX_HISTORY_SERVICE_HOST=history-service.peerprep-prod.internal
NGINX_COLLABORATION_SERVICE_HOST=collaboration-service.peerprep-prod.internal
NGINX_CHAT_SERVICE_HOST=chat-service.peerprep-prod.internal

# -----------------------------------------------------------------------------
# Managed Services (RDS, ElastiCache)
# -----------------------------------------------------------------------------
# Redis Configuration (AWS ElastiCache)
MATCHING_REDIS_HOST=peerprep-redis.xxxxxx.ng.0001.use1.cache.amazonaws.com
MATCHING_REDIS_PORT=6379
COLLABORATION_REDIS_HOST=peerprep-redis.xxxxxx.ng.0001.use1.cache.amazonaws.com
COLLABORATION_REDIS_PORT=6379
CHAT_REDIS_HOST=peerprep-redis.xxxxxx.ng.0001.use1.cache.amazonaws.com
CHAT_REDIS_PORT=6379

MATCHING_REDIS_URL=redis://peerprep-redis.xxxxxx.ng.0001.use1.cache.amazonaws.com:6379/0
COLLABORATION_REDIS_URL=redis://peerprep-redis.xxxxxx.ng.0001.use1.cache.amazonaws.com:6379/1
CHAT_REDIS_URL=redis://peerprep-redis.xxxxxx.ng.0001.use1.cache.amazonaws.com:6379/2

# Database Configuration (AWS RDS PostgreSQL)
QUESTION_DB_HOST=peerprep-db.xxxxxx.us-east-1.rds.amazonaws.com
QUESTION_DB_PORT=5432
QUESTION_DB_NAME=question_db
QUESTION_DB_USER=peerprep_admin
QUESTION_DB_PASSWORD=CHANGEME_SECURE_PASSWORD

MATCHING_DB_HOST=peerprep-db.xxxxxx.us-east-1.rds.amazonaws.com
MATCHING_DB_PORT=5432
MATCHING_DB_NAME=matching_db
MATCHING_DB_USER=peerprep_admin
MATCHING_DB_PASSWORD=CHANGEME_SECURE_PASSWORD

HISTORY_DB_HOST=peerprep-db.xxxxxx.us-east-1.rds.amazonaws.com
HISTORY_DB_PORT=5432
HISTORY_DB_NAME=history_db
HISTORY_DB_USER=peerprep_admin
HISTORY_DB_PASSWORD=CHANGEME_SECURE_PASSWORD

USER_DB_HOST=peerprep-db.xxxxxx.us-east-1.rds.amazonaws.com
USER_DB_PORT=5432
USER_DB_NAME=user_db
USER_DB_USER=peerprep_admin
USER_DB_PASSWORD=CHANGEME_SECURE_PASSWORD

# Database URLs
QUESTION_DATABASE_URL=postgresql://peerprep_admin:CHANGEME_SECURE_PASSWORD@peerprep-db.xxxxxx.us-east-1.rds.amazonaws.com:5432/question_db
MATCHING_DATABASE_URL=postgresql://peerprep_admin:CHANGEME_SECURE_PASSWORD@peerprep-db.xxxxxx.us-east-1.rds.amazonaws.com:5432/matching_db
HISTORY_DATABASE_URL=postgresql://peerprep_admin:CHANGEME_SECURE_PASSWORD@peerprep-db.xxxxxx.us-east-1.rds.amazonaws.com:5432/history_db
USER_DATABASE_URL=postgresql://peerprep_admin:CHANGEME_SECURE_PASSWORD@peerprep-db.xxxxxx.us-east-1.rds.amazonaws.com:5432/user_db

# -----------------------------------------------------------------------------
# Django Configuration (Production)
# -----------------------------------------------------------------------------
DEBUG=false
SECRET_KEY=CHANGEME_PRODUCTION_SECRET_KEY_MIN_50_CHARS_RANDOM
ALLOWED_HOSTS=peerprep.com,*.peerprep.com,10.0.0.0/8

# -----------------------------------------------------------------------------
# Frontend Environment Variables (Production)
# -----------------------------------------------------------------------------
# Browser accesses APIs through Nginx proxy paths
NODE_ENV=production
VITE_QUESTION_SERVICE_URL=/question-service-api
VITE_MATCHING_SERVICE_URL=/matching-service-api
VITE_HISTORY_SERVICE_URL=/history-service-api
VITE_USER_SERVICE_URL=/user-service-api
VITE_COLLABORATION_SERVICE_URL=/collaboration-service-api
VITE_CHAT_SERVICE_URL=/chat-service-api
```

---

### Phase 4: Nginx Configuration 🌐

#### `frontend/nginx.conf.template`

**Key Features:**
- ✅ Environment variable substitution (`${VAR}` replaced at runtime)
- ✅ Path prefix stripping (`/user-service-api/login` → `/login`)
- ✅ WebSocket support for chat/collaboration
- ✅ CORS headers
- ✅ Gzip compression

```nginx
# =============================================================================
# PeerPrep Frontend - Nginx Configuration Template
# =============================================================================
# This file uses environment variable substitution via envsubst
# Variables are replaced when the container starts
#
# Environment Variables Required:
#   NGINX_USER_SERVICE_HOST
#   NGINX_QUESTION_SERVICE_HOST
#   NGINX_MATCHING_SERVICE_HOST
#   NGINX_HISTORY_SERVICE_HOST
#   NGINX_COLLABORATION_SERVICE_HOST
#   NGINX_CHAT_SERVICE_HOST
# =============================================================================

server {
    listen 80;
    server_name localhost;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml+rss;

    # ==========================================================================
    # Frontend Static Files (React SPA)
    # ==========================================================================
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;

        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # ==========================================================================
    # API Proxy Rules - Pattern: /service-name-api/* → http://service:8000/*
    # ==========================================================================

    # User Service API
    # Browser: /user-service-api/login → Backend: /login
    location /user-service-api/ {
        rewrite ^/user-service-api/(.*)$ /$1 break;
        proxy_pass http://${NGINX_USER_SERVICE_HOST}:8000;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # CORS handling (if needed)
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;

        if ($request_method = OPTIONS) {
            return 204;
        }
    }

    # Question Service API
    location /question-service-api/ {
        rewrite ^/question-service-api/(.*)$ /$1 break;
        proxy_pass http://${NGINX_QUESTION_SERVICE_HOST}:8000;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Matching Service API
    location /matching-service-api/ {
        rewrite ^/matching-service-api/(.*)$ /$1 break;
        proxy_pass http://${NGINX_MATCHING_SERVICE_HOST}:8000;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # History Service API
    location /history-service-api/ {
        rewrite ^/history-service-api/(.*)$ /$1 break;
        proxy_pass http://${NGINX_HISTORY_SERVICE_HOST}:8000;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Collaboration Service API (WebSocket support)
    location /collaboration-service-api/ {
        rewrite ^/collaboration-service-api/(.*)$ /$1 break;
        proxy_pass http://${NGINX_COLLABORATION_SERVICE_HOST}:8000;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    # Chat Service API (WebSocket support)
    location /chat-service-api/ {
        rewrite ^/chat-service-api/(.*)$ /$1 break;
        proxy_pass http://${NGINX_CHAT_SERVICE_HOST}:8000;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

---

### Phase 5: Frontend Dockerfile Update 🐳

#### `frontend/Dockerfile` - Multi-Stage Build

```dockerfile
# =============================================================================
# Stage 1: Development (Vite Dev Server)
# =============================================================================
FROM node:22-slim AS development

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .
EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]

# =============================================================================
# Stage 2: Build (Production Assets)
# =============================================================================
FROM node:22-slim AS build

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

# =============================================================================
# Stage 3: Production (Nginx + Static Files)
# =============================================================================
FROM nginx:alpine AS production

# Install envsubst (part of gettext package)
RUN apk add --no-cache gettext

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy nginx template
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# Copy built static files from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Create startup script that performs envsubst
RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Substitute environment variables in nginx config' >> /docker-entrypoint.sh && \
    echo 'envsubst "$(env | sed -e "s/=.*//" -e "s/^/\$/g")" < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Start nginx' >> /docker-entrypoint.sh && \
    echo 'exec nginx -g "daemon off;"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
```

#### `frontend/docker-compose.yml` - Updated for Multi-Stage

```yaml
# Frontend Service - Standalone Configuration
# Development: Uses 'development' stage (Vite dev server)
# Production: Uses 'production' stage (Nginx)

services:
  frontend:
    build:
      context: .
      dockerfile: Dockerfile
      target: ${FRONTEND_BUILD_STAGE:-development}  # development | production
    container_name: peerprep_frontend
    ports:
      - "${FRONTEND_PORT:-5173}:${FRONTEND_INTERNAL_PORT:-5173}"
    environment:
      # Frontend build-time variables (Vite)
      - NODE_ENV=${ENVIRONMENT:-development}
      - VITE_QUESTION_SERVICE_URL=${VITE_QUESTION_SERVICE_URL:-http://localhost:8001}
      - VITE_MATCHING_SERVICE_URL=${VITE_MATCHING_SERVICE_URL:-http://localhost:8002}
      - VITE_HISTORY_SERVICE_URL=${VITE_HISTORY_SERVICE_URL:-http://localhost:8003}
      - VITE_USER_SERVICE_URL=${VITE_USER_SERVICE_URL:-http://localhost:8004}
      - VITE_COLLABORATION_SERVICE_URL=${VITE_COLLABORATION_SERVICE_URL:-http://localhost:8005}
      - VITE_CHAT_SERVICE_URL=${VITE_CHAT_SERVICE_URL:-http://localhost:8006}

      # Nginx runtime variables (production only)
      - NGINX_USER_SERVICE_HOST=${NGINX_USER_SERVICE_HOST:-user-service}
      - NGINX_QUESTION_SERVICE_HOST=${NGINX_QUESTION_SERVICE_HOST:-question-service}
      - NGINX_MATCHING_SERVICE_HOST=${NGINX_MATCHING_SERVICE_HOST:-matching-service}
      - NGINX_HISTORY_SERVICE_HOST=${NGINX_HISTORY_SERVICE_HOST:-history-service}
      - NGINX_COLLABORATION_SERVICE_HOST=${NGINX_COLLABORATION_SERVICE_HOST:-collaboration-service}
      - NGINX_CHAT_SERVICE_HOST=${NGINX_CHAT_SERVICE_HOST:-chat-service}
    volumes:
      # Development only (commented out in production)
      - ./src:/app/src:ro
      - ./public:/app/public:ro
      - /app/node_modules
    networks:
      - shared_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${FRONTEND_INTERNAL_PORT:-5173}"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  shared_network:
    external: true
    name: peerprep_shared_network
```

**Usage:**

```bash
# Development (Vite dev server)
FRONTEND_BUILD_STAGE=development docker-compose up

# Production (Nginx)
FRONTEND_BUILD_STAGE=production FRONTEND_INTERNAL_PORT=80 docker-compose up
```

---

## Detailed Changes

### Service-by-Service Docker Compose Updates

#### 1. User Service

**File:** `user_service/docker-compose.yml`

```yaml
services:
  user-service:  # ← CHANGED from user_service
    build:
      context: .
      dockerfile: Dockerfile
    container_name: peerprep_user_service  # Keep underscore (container name, not hostname)
    ports:
      - "${USER_SERVICE_PORT:-8004}:8000"
    environment:
      - DEBUG=${DEBUG:-true}
      - SECRET_KEY=${SECRET_KEY:-dev-secret-key}
      - ALLOWED_HOSTS=${ALLOWED_HOSTS:-localhost,127.0.0.1,user-service}  # ← ADD service name
      - DATABASE_URL=${USER_DATABASE_URL}
      - DB_HOST=${USER_DB_HOST:-user_db}
      - DB_PORT=${USER_DB_PORT:-5432}
      - DB_NAME=${USER_DB_NAME:-user_db}
      - DB_USER=${USER_DB_USER:-peerprep}
      - DB_PASSWORD=${USER_DB_PASSWORD:-peerprep_dev_password}

      # Add service URLs for inter-service communication
      - QUESTION_SERVICE_URL=${QUESTION_SERVICE_URL}
      - MATCHING_SERVICE_URL=${MATCHING_SERVICE_URL}
      - HISTORY_SERVICE_URL=${HISTORY_SERVICE_URL}
    volumes:
      - ./:/app:rw
    networks:
      - shared_network
      - user_network
    depends_on:
      user_db:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  user_db:
    image: postgres:15-alpine
    container_name: peerprep_user_db
    environment:
      - POSTGRES_DB=${USER_DB_NAME:-user_db}
      - POSTGRES_USER=${USER_DB_USER:-peerprep}
      - POSTGRES_PASSWORD=${USER_DB_PASSWORD:-peerprep_dev_password}
    volumes:
      - user_db_data:/var/lib/postgresql/data
    networks:
      - user_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${USER_DB_USER:-peerprep} -d ${USER_DB_NAME:-user_db}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  user_db_data:
    name: peerprep_user_db_data

networks:
  shared_network:
    external: true
    name: peerprep_shared_network
  user_network:
    driver: bridge
    name: peerprep_user_network
```

**Changes:**
- ✅ Service name: `user_service` → `user-service`
- ✅ Added service name to `ALLOWED_HOSTS`
- ✅ Added environment variables for other service URLs

---

#### 2. Collaboration Service (Port Change Required)

**File:** `collaboration_service/docker-compose.yml`

```yaml
services:
  collaboration-service:  # ← CHANGED from collaboration_service
    build:
      context: .
      dockerfile: Dockerfile
    container_name: peerprep_collaboration_service
    ports:
      - "${COLLABORATION_SERVICE_PORT:-8005}:8000"  # ← CHANGED from :8005 to :8000
    environment:
      - DEBUG=${DEBUG:-true}
      - PORT=8000  # ← CHANGED from 8005
      - REDIS_URL=${COLLABORATION_REDIS_URL}
      - REDIS_HOST=${COLLABORATION_REDIS_HOST:-collaboration_redis}
      - REDIS_PORT=${COLLABORATION_REDIS_PORT:-6379}

      # Add service URLs
      - USER_SERVICE_URL=${USER_SERVICE_URL}
      - QUESTION_SERVICE_URL=${QUESTION_SERVICE_URL}
    volumes:
      - ./:/app:rw
    networks:
      - shared_network
      - collaboration_network
    depends_on:
      collaboration_redis:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]  # ← CHANGED from :8005
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  collaboration_redis:
    image: redis:7-alpine
    container_name: peerprep_collaboration_redis
    command: redis-server --appendonly yes
    volumes:
      - collaboration_redis_data:/data
    networks:
      - collaboration_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  collaboration_redis_data:
    name: peerprep_collaboration_redis_data

networks:
  shared_network:
    external: true
    name: peerprep_shared_network
  collaboration_network:
    driver: bridge
    name: peerprep_collaboration_network
```

**⚠️ CODE CHANGES REQUIRED:**
The application code must be updated to listen on port 8000 instead of 8005.

---

#### 3. Chat Service (Port Change Required)

**File:** `chat_service/docker-compose.yml`

```yaml
services:
  chat-service:  # ← CHANGED from chat_service
    build:
      context: .
      dockerfile: Dockerfile
    container_name: peerprep_chat_service
    ports:
      - "${CHAT_SERVICE_PORT:-8006}:8000"  # ← CHANGED from :8006 to :8000
    environment:
      - DEBUG=${DEBUG:-true}
      - PORT=8000  # ← CHANGED from 8006
      - REDIS_URL=${CHAT_REDIS_URL}
      - REDIS_HOST=${CHAT_REDIS_HOST:-chat_redis}
      - REDIS_PORT=${CHAT_REDIS_PORT:-6379}

      # Add service URLs
      - USER_SERVICE_URL=${USER_SERVICE_URL}
      - COLLABORATION_SERVICE_URL=${COLLABORATION_SERVICE_URL}
    volumes:
      - ./:/app:rw
    networks:
      - shared_network
      - chat_network
    depends_on:
      chat_redis:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]  # ← CHANGED from :8006
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  chat_redis:
    image: redis:7-alpine
    container_name: peerprep_chat_redis
    command: redis-server --appendonly yes
    volumes:
      - chat_redis_data:/data
    networks:
      - chat_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  chat_redis_data:
    name: peerprep_chat_redis_data

networks:
  shared_network:
    external: true
    name: peerprep_shared_network
  chat_network:
    driver: bridge
    name: peerprep_chat_network
```

**⚠️ CODE CHANGES REQUIRED:**
The application code must be updated to listen on port 8000 instead of 8006.

---

#### 4-6. Question/Matching/History Services

Similar changes to User Service:
- Service name: `*_service` → `*-service`
- Add service name to `ALLOWED_HOSTS`
- Add service URL environment variables

*(Full configs omitted for brevity - follow User Service pattern)*

---

## Migration Guide

### Backend Code Changes Required

#### Django Services (User, Question, History)

**File:** `*/settings.py`

```python
# Add service URLs for inter-service communication
USER_SERVICE_URL = os.environ.get('USER_SERVICE_URL', 'http://user-service:8000')
QUESTION_SERVICE_URL = os.environ.get('QUESTION_SERVICE_URL', 'http://question-service:8000')
MATCHING_SERVICE_URL = os.environ.get('MATCHING_SERVICE_URL', 'http://matching-service:8000')
HISTORY_SERVICE_URL = os.environ.get('HISTORY_SERVICE_URL', 'http://history-service:8000')
COLLABORATION_SERVICE_URL = os.environ.get('COLLABORATION_SERVICE_URL', 'http://collaboration-service:8000')
CHAT_SERVICE_URL = os.environ.get('CHAT_SERVICE_URL', 'http://chat-service:8000')
```

**Usage in views:**

```python
from django.conf import settings
import requests

def call_user_service(user_id):
    url = f"{settings.USER_SERVICE_URL}/api/users/{user_id}"
    response = requests.get(url)
    return response.json()
```

---

#### Node.js Services (Collaboration, Chat, Matching)

**Collaboration Service - Port Change**

**File:** `collaboration_service/index.js` (or `server.js`)

```javascript
// BEFORE
const PORT = process.env.PORT || 8005;

// AFTER
const PORT = process.env.PORT || 8000;

app.listen(PORT, () => {
  console.log(`Collaboration service listening on port ${PORT}`);
});
```

**Add service URLs:**

```javascript
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://user-service:8000';
const QUESTION_SERVICE_URL = process.env.QUESTION_SERVICE_URL || 'http://question-service:8000';

// Example usage
const axios = require('axios');

async function getUserData(userId) {
  const response = await axios.get(`${USER_SERVICE_URL}/api/users/${userId}`);
  return response.data;
}
```

---

**Chat Service - Port Change**

**File:** `chat_service/index.js` (or `server.js`)

```javascript
// BEFORE
const PORT = process.env.PORT || 8006;

// AFTER
const PORT = process.env.PORT || 8000;

app.listen(PORT, () => {
  console.log(`Chat service listening on port ${PORT}`);
});
```

---

### Frontend Code Changes

**File:** `frontend/src/config/api.ts` (or similar)

```typescript
// Base URL changes based on environment
const BASE_URL = import.meta.env.PROD ? '' : 'http://localhost';

// Service API endpoints
export const API_ENDPOINTS = {
  // In production: /user-service-api (proxied by nginx)
  // In development: http://localhost:8004 (direct access)
  USER_SERVICE: import.meta.env.PROD
    ? '/user-service-api'
    : `${BASE_URL}:8004`,

  QUESTION_SERVICE: import.meta.env.PROD
    ? '/question-service-api'
    : `${BASE_URL}:8001`,

  MATCHING_SERVICE: import.meta.env.PROD
    ? '/matching-service-api'
    : `${BASE_URL}:8002`,

  HISTORY_SERVICE: import.meta.env.PROD
    ? '/history-service-api'
    : `${BASE_URL}:8003`,

  COLLABORATION_SERVICE: import.meta.env.PROD
    ? '/collaboration-service-api'
    : `${BASE_URL}:8005`,  // Still 8005 externally in dev

  CHAT_SERVICE: import.meta.env.PROD
    ? '/chat-service-api'
    : `${BASE_URL}:8006`,  // Still 8006 externally in dev
} as const;
```

**Usage:**

```typescript
import { API_ENDPOINTS } from '@/config/api';

// Frontend makes request to /user-service-api/login
// Nginx strips prefix, forwards to user-service:8000/login
async function login(email: string, password: string) {
  const response = await fetch(`${API_ENDPOINTS.USER_SERVICE}/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  return response.json();
}
```

---

## Testing Strategy

### Local Development Testing

```bash
# 1. Recreate shared network
docker network create peerprep_shared_network

# 2. Start services
docker-compose up --build

# 3. Test service discovery (from inside a container)
docker exec -it peerprep_user_service curl http://question-service:8000/health

# 4. Test frontend proxy (dev mode)
curl http://localhost:5173

# 5. Test backend direct access (dev mode)
curl http://localhost:8004/health  # user service
```

### Production Build Testing

```bash
# 1. Build frontend with production target
cd frontend
FRONTEND_BUILD_STAGE=production docker-compose up --build

# 2. Test nginx proxy
curl http://localhost/user-service-api/health
# Should proxy to user-service:8000/health

# 3. Test static files
curl http://localhost/
# Should serve React app
```

### Inter-Service Communication Testing

Create a test endpoint in each service:

```python
# Django example (user_service/views.py)
from django.http import JsonResponse
import requests

def test_service_discovery(request):
    services = {
        'question': settings.QUESTION_SERVICE_URL,
        'matching': settings.MATCHING_SERVICE_URL,
    }

    results = {}
    for name, url in services.items():
        try:
            response = requests.get(f"{url}/health", timeout=5)
            results[name] = {
                'status': 'healthy' if response.status_code == 200 else 'unhealthy',
                'url': url
            }
        except Exception as e:
            results[name] = {
                'status': 'unreachable',
                'error': str(e),
                'url': url
            }

    return JsonResponse(results)
```

**Test:**

```bash
curl http://localhost:8004/test-service-discovery
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] All service names changed to hyphenated format
- [ ] All services expose port 8000 internally
- [ ] Collaboration/Chat services updated to listen on port 8000
- [ ] `.env` updated with service URLs
- [ ] `.env.prod` created with ECS service discovery URLs
- [ ] `frontend/nginx.conf.template` created
- [ ] `frontend/Dockerfile` updated to multi-stage build
- [ ] Frontend code updated to use proxy paths in production
- [ ] Backend code updated to use service URL environment variables

### Testing

- [ ] Local Docker Compose: All services start successfully
- [ ] Service-to-service communication works (curl from container to container)
- [ ] Frontend development mode works (Vite dev server)
- [ ] Frontend production mode works (Nginx build)
- [ ] Nginx proxy routes correctly (`/user-service-api/*` → `user-service:8000/*`)
- [ ] WebSocket connections work for chat/collaboration

### Production (ECS)

- [ ] Create ECS service discovery namespace: `peerprep-prod.internal`
- [ ] Configure each ECS service with service discovery
- [ ] Update task definitions with `.env.prod` values
- [ ] Configure ALB to route to frontend ECS service
- [ ] Set up RDS PostgreSQL (replace local databases)
- [ ] Set up ElastiCache Redis (replace local Redis)
- [ ] Update security groups to allow inter-service communication
- [ ] Deploy and test in staging environment first

---

## Rollback Plan

If issues occur:

1. **Revert service names:**
   ```bash
   git checkout HEAD~1 -- */docker-compose.yml
   ```

2. **Restart with old configuration:**
   ```bash
   docker-compose down
   docker-compose up --build
   ```

3. **Preserve data:**
   - Docker volumes are named (e.g., `peerprep_user_db_data`)
   - Data persists across container recreations
   - Backup volumes before major changes:
     ```bash
     docker run --rm -v peerprep_user_db_data:/data -v $(pwd):/backup \
       alpine tar czf /backup/user_db_backup.tar.gz /data
     ```

---

## Next Steps

1. **Review this plan with team**
2. **Create feature branch:** `feat/service-discovery-nginx`
3. **Implement changes incrementally:**
   - Phase 1: Service naming
   - Phase 2: Port standardization
   - Phase 3: Environment variables
   - Phase 4: Nginx configuration
   - Phase 5: Frontend Dockerfile
4. **Test locally at each phase**
5. **Document any additional findings**
6. **Merge to main after thorough testing**

---

## Reference Architecture Diagrams

### Request Flow - Development

```
Browser
  │
  ├─► http://localhost:5173 ────────────┐
  │                                     │
  └─► http://localhost:8004/api/users  │
         (Direct to User Service)       │
                                        ▼
┌───────────────────────────────────────────────┐
│         Docker: peerprep_shared_network       │
│                                               │
│  ┌──────────┐          ┌────────────┐        │
│  │ Frontend │          │ User       │        │
│  │ (Vite)   │          │ Service    │        │
│  │  :5173   │          │ :8000      │        │
│  └──────────┘          └────────────┘        │
│                              │                │
│                              │ Backend calls  │
│                              ▼                │
│  ┌─────────────────────────────────┐         │
│  │ http://question-service:8000    │         │
│  └─────────────────────────────────┘         │
└───────────────────────────────────────────────┘
```

### Request Flow - Production (ECS)

```
Browser
  │
  └─► https://peerprep.com/user-service-api/login
         │
┌────────▼────────────────────────────────────────┐
│           Application Load Balancer             │
└────────┬────────────────────────────────────────┘
         │
┌────────▼────────────────────────────────────────┐
│              ECS: peerprep-prod                 │
│                                                 │
│  ┌─────────────────────────────────┐           │
│  │ Frontend Task (Nginx)           │           │
│  │                                 │           │
│  │ Nginx receives:                 │           │
│  │ /user-service-api/login         │           │
│  │                                 │           │
│  │ Strips prefix, proxies to:     │           │
│  │ http://${NGINX_USER_SERVICE_    │           │
│  │        HOST}:8000/login         │           │
│  │                                 │           │
│  │ Resolves via envsubst:          │           │
│  │ http://user-service.peerprep-   │           │
│  │        prod.internal:8000/login │           │
│  └────────────┬────────────────────┘           │
│               │                                 │
│               │ ECS Service Discovery DNS       │
│               ▼                                 │
│  ┌────────────────────────────────┐            │
│  │ User Service Task              │            │
│  │ Port: 8000                     │            │
│  │                                │            │
│  │ Backend-to-Backend:            │            │
│  │ http://question-service.       │            │
│  │   peerprep-prod.internal:8000  │            │
│  └────────────────────────────────┘            │
└─────────────────────────────────────────────────┘
```

---

**Document Version:** 1.0
**Last Updated:** 2025-10-08
**Author:** Claude Code Planning Agent
**Status:** Ready for Implementation
