# Environment Variables Configuration for ECS Services

This document details all environment variables that will be configured for each ECS service. **PLEASE REVIEW CAREFULLY** before running `terraform apply`.

## Service Discovery DNS Names

All backend services will be accessible via Cloud Map DNS:
```
user-service.peerprep-prod.local
question-service.peerprep-prod.local
matching-service.peerprep-prod.local
history-service.peerprep-prod.local
collaboration-service.peerprep-prod.local
chat-service.peerprep-prod.local
```

---

## 1. User Service

**Container Port:** 8000
**Database:** user_db (RDS PostgreSQL)
**Dependencies:** All other backend services

### Environment Variables:
```bash
# Django/FastAPI Configuration
DEBUG=false
SECRET_KEY=<from terraform variable>
ALLOWED_HOSTS=<ALB DNS name>,user-service,user-service.peerprep-prod.local

# Database Connection
DATABASE_URL=postgresql://peerprep_admin:<password>@<rds-user-endpoint>:5432/user_db
DB_HOST=<rds-user-host>
DB_PORT=5432
DB_NAME=user_db
DB_USER=peerprep_admin
DB_PASSWORD=<from terraform variable>

# Service-to-Service URLs (via Service Discovery)
QUESTION_SERVICE_URL=http://question-service.peerprep-prod.local:8000
MATCHING_SERVICE_URL=http://matching-service.peerprep-prod.local:8000
HISTORY_SERVICE_URL=http://history-service.peerprep-prod.local:8000
COLLABORATION_SERVICE_URL=http://collaboration-service.peerprep-prod.local:8000
CHAT_SERVICE_URL=http://chat-service.peerprep-prod.local:8000
```

---

## 2. Question Service

**Container Port:** 8000
**Database:** question_db (RDS PostgreSQL)
**Dependencies:** user-service, matching-service, history-service

### Environment Variables:
```bash
# Django/FastAPI Configuration
DEBUG=false
SECRET_KEY=<from terraform variable>
ALLOWED_HOSTS=<ALB DNS name>,question-service,question-service.peerprep-prod.local
DJANGO_USE_SQLITE=0

# Database Connection
DATABASE_URL=postgresql://peerprep_admin:<password>@<rds-question-endpoint>:5432/question_db
DB_HOST=<rds-question-host>
DB_PORT=5432
DB_NAME=question_db
DB_USER=peerprep_admin
DB_PASSWORD=<from terraform variable>

# Service-to-Service URLs
USER_SERVICE_URL=http://user-service.peerprep-prod.local:8000
MATCHING_SERVICE_URL=http://matching-service.peerprep-prod.local:8000
HISTORY_SERVICE_URL=http://history-service.peerprep-prod.local:8000
```

---

## 3. Matching Service

**Container Port:** 8000
**Database:** matching_db (RDS PostgreSQL)
**Cache:** matching Redis (ElastiCache)
**Dependencies:** user-service, question-service

### Environment Variables:
```bash
# Django/FastAPI Configuration
DEBUG=false
ALLOWED_HOSTS=<ALB DNS name>,matching-service,matching-service.peerprep-prod.local

# Database Connection
DATABASE_URL=postgresql://peerprep_admin:<password>@<rds-matching-endpoint>:5432/matching_db
DB_HOST=<rds-matching-host>
DB_PORT=5432
DB_NAME=matching_db
DB_USER=peerprep_admin
DB_PASSWORD=<from terraform variable>

# Redis Connection
REDIS_URL=redis://<redis-matching-endpoint>:6379/0
REDIS_HOST=<redis-matching-endpoint>
REDIS_PORT=6379

# Service-to-Service URLs
USER_SERVICE_URL=http://user-service.peerprep-prod.local:8000
QUESTION_SERVICE_URL=http://question-service.peerprep-prod.local:8000
```

---

## 4. History Service

**Container Port:** 8000
**Database:** history_db (RDS PostgreSQL)
**Dependencies:** user-service, question-service, collaboration-service

### Environment Variables:
```bash
# Django/FastAPI Configuration
DEBUG=false
SECRET_KEY=<from terraform variable>
ALLOWED_HOSTS=<ALB DNS name>,history-service,history-service.peerprep-prod.local

# Database Connection
DATABASE_URL=postgresql://peerprep_admin:<password>@<rds-history-endpoint>:5432/history_db
DB_HOST=<rds-history-host>
DB_PORT=5432
DB_NAME=history_db
DB_USER=peerprep_admin
DB_PASSWORD=<from terraform variable>

# Service-to-Service URLs
USER_SERVICE_URL=http://user-service.peerprep-prod.local:8000
QUESTION_SERVICE_URL=http://question-service.peerprep-prod.local:8000
COLLABORATION_SERVICE_URL=http://collaboration-service.peerprep-prod.local:8000
```

---

## 5. Collaboration Service (WebSocket)

**Container Port:** 8000
**Cache:** collaboration Redis (ElastiCache)
**Dependencies:** user-service, question-service, chat-service

### Environment Variables:
```bash
# FastAPI Configuration
DEBUG=false
PORT=8000

# Redis Connection (for WebSocket session management)
REDIS_URL=redis://<redis-collaboration-endpoint>:6379/0
REDIS_HOST=<redis-collaboration-endpoint>
REDIS_PORT=6379

# Service-to-Service URLs
USER_SERVICE_URL=http://user-service.peerprep-prod.local:8000
QUESTION_SERVICE_URL=http://question-service.peerprep-prod.local:8000
CHAT_SERVICE_URL=http://chat-service.peerprep-prod.local:8000
```

---

## 6. Chat Service (WebSocket)

**Container Port:** 8000
**Cache:** chat Redis (ElastiCache)
**Dependencies:** user-service, collaboration-service

### Environment Variables:
```bash
# FastAPI Configuration
DEBUG=false
PORT=8000

# Redis Connection (for WebSocket session management)
REDIS_URL=redis://<redis-chat-endpoint>:6379/0
REDIS_HOST=<redis-chat-endpoint>
REDIS_PORT=6379

# Service-to-Service URLs
USER_SERVICE_URL=http://user-service.peerprep-prod.local:8000
COLLABORATION_SERVICE_URL=http://collaboration-service.peerprep-prod.local:8000
```

---

## 7. Frontend (React + Nginx)

**Container Port:** 80
**Note:** Frontend proxies API requests to backend services

### Environment Variables (Nginx):
```bash
# Node environment
NODE_ENV=production

# Nginx proxy configuration (service hostnames for proxy_pass)
NGINX_USER_SERVICE_HOST=user-service.peerprep-prod.local
NGINX_QUESTION_SERVICE_HOST=question-service.peerprep-prod.local
NGINX_MATCHING_SERVICE_HOST=matching-service.peerprep-prod.local
NGINX_HISTORY_SERVICE_HOST=history-service.peerprep-prod.local
NGINX_COLLABORATION_SERVICE_HOST=collaboration-service.peerprep-prod.local
NGINX_CHAT_SERVICE_HOST=chat-service.peerprep-prod.local

# VITE build-time variables (embedded in JS bundle)
VITE_QUESTION_SERVICE_URL=/question-service-api
VITE_MATCHING_SERVICE_URL=/matching-service-api
VITE_HISTORY_SERVICE_URL=/history-service-api
VITE_USER_SERVICE_URL=/user-service-api
VITE_COLLABORATION_SERVICE_URL=/collaboration-service-api
VITE_CHAT_SERVICE_URL=/chat-service-api
```

---

## Verification Checklist

Before deploying, verify:

### Database Connections
- [ ] user-service → user_db RDS instance
- [ ] question-service → question_db RDS instance
- [ ] matching-service → matching_db RDS instance
- [ ] history-service → history_db RDS instance

### Redis Connections
- [ ] matching-service → matching Redis cluster
- [ ] collaboration-service → collaboration Redis cluster
- [ ] chat-service → chat Redis cluster

### Service Discovery
- [ ] All services can communicate via `<service>.peerprep-prod.local`
- [ ] Service-to-service URLs use internal DNS names
- [ ] No hardcoded IP addresses

### Secrets
- [ ] `SECRET_KEY` is set securely (not default value)
- [ ] `DB_PASSWORD` matches terraform.tfvars configuration
- [ ] No passwords in plaintext (consider AWS Secrets Manager)

### Frontend Configuration
- [ ] Nginx proxy hosts point to service discovery names
- [ ] VITE URLs use proxy paths (not direct service URLs)
- [ ] NODE_ENV set to production

---

## How Environment Variables Are Set

Terraform will create these environment variables in ECS task definitions using:

1. **Direct values:** For non-sensitive configuration
2. **Terraform outputs:** For dynamic values (RDS endpoints, Redis endpoints)
3. **Terraform variables:** For secrets (db_password, secret_key)
4. **Service Discovery:** For inter-service communication

---

## Security Recommendations

### Before Production:
1. **Use AWS Secrets Manager** for sensitive values:
   - Database passwords
   - SECRET_KEY
   - API keys

2. **Rotate secrets regularly**

3. **Use IAM roles** for AWS service access (already configured)

4. **Enable encryption in transit** for Redis (if needed)

5. **Review ALLOWED_HOSTS** to include only your domain

---

## Testing Environment Variables

After deployment, test each service:

```bash
# Get ALB DNS name
terraform output alb_dns_name

# Test each service health endpoint
curl http://<alb-dns>/user-service-api/health
curl http://<alb-dns>/question-service-api/health
curl http://<alb-dns>/matching-service-api/health
curl http://<alb-dns>/history-service-api/health
curl http://<alb-dns>/collaboration-service-api/health
curl http://<alb-dns>/chat-service-api/health
```

If any service fails, check:
1. CloudWatch logs: `/ecs/peerprep-prod/<service-name>`
2. ECS task health status
3. Environment variable configuration
4. Database/Redis connectivity

---

## Questions to Ask Before Deployment

1. Are all database passwords secure and not using defaults?
2. Is SECRET_KEY unique and complex?
3. Do all service-to-service URLs use the correct internal DNS names?
4. Are frontend Nginx proxy hosts correctly configured?
5. Do WebSocket services (collaboration, chat) have sticky sessions enabled in ALB?

**If you answer "no" to any question, DO NOT deploy yet!**
