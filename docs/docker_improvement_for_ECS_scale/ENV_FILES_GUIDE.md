# Environment Files Guide

## 📁 File Structure

```
project/
├── .env                    # Active development config (gitignored)
├── .env.sample             # Development template (committed to git)
├── .env.prod               # Active production config (gitignored)
└── .env.prod.sample        # Production template (committed to git)
```

---

## 🔐 Security Best Practices

### ✅ COMMIT to Git:
- `.env.sample` - Safe template with no secrets
- `.env.prod.sample` - Safe template with placeholder values

### ❌ NEVER Commit to Git:
- `.env` - Contains development database passwords
- `.env.prod` - Contains production secrets

---

## 📋 File Usage

### `.env.sample`
**Purpose:** Template for local development setup

**Usage:**
```bash
# First time setup
cp .env.sample .env

# Customize if needed (usually works as-is for Docker)
```

**Contains:**
- Docker service names (`user-service`, `question-service`)
- Development database credentials (safe for local Docker)
- Service discovery URLs for inter-service communication
- Nginx proxy configuration

---

### `.env`
**Purpose:** Active development configuration

**Status:** ✅ Already exists and configured

**Contains:**
- Same structure as `.env.sample`
- Updated with:
  - Hyphenated service names
  - Service-to-service URLs
  - Nginx proxy paths (`/user-service-api`)

**DO NOT** commit this file (already in `.gitignore`)

---

### `.env.prod.sample`
**Purpose:** Template for production deployment (AWS ECS)

**Usage:**
```bash
# When deploying to production
cp .env.prod.sample .env.prod

# Fill in actual values:
# - AWS RDS endpoints
# - ElastiCache endpoints
# - Production secrets
# - Domain names
```

**Contains:**
- ECS service discovery URLs
- Placeholder AWS service endpoints
- Production configuration template

---

### `.env.prod`
**Purpose:** Active production configuration

**Status:** ✅ Created with template values

**Next Steps:**
1. Replace all `CHANGEME_*` values
2. Update AWS endpoints (RDS, ElastiCache)
3. Generate production SECRET_KEY
4. Update ALLOWED_HOSTS with your domain

**DO NOT** commit this file to git!

**Storage:** Use AWS Secrets Manager or Parameter Store in production

---

## 🎯 Environment Variable Naming Convention

We use **`.env.prod`** (not `.env.production`) for consistency:

| File | Usage | Commit to Git? |
|------|-------|----------------|
| `.env` | Development active | ❌ No |
| `.env.sample` | Development template | ✅ Yes |
| `.env.prod` | Production active | ❌ No |
| `.env.prod.sample` | Production template | ✅ Yes |

---

## 🔄 Key Differences: Development vs Production

### Service Discovery URLs

**Development (`.env`):**
```bash
USER_SERVICE_URL=http://user-service:8000
NGINX_USER_SERVICE_HOST=user-service
```
→ Uses Docker DNS

**Production (`.env.prod`):**
```bash
USER_SERVICE_URL=http://user-service.peerprep-prod.internal:8000
NGINX_USER_SERVICE_HOST=user-service.peerprep-prod.internal
```
→ Uses ECS Service Discovery

### Frontend API URLs

**SAME in both environments:**
```bash
VITE_USER_SERVICE_URL=/user-service-api
```
→ Nginx proxies to backend (environment-agnostic!)

### Database/Redis

**Development:**
```bash
USER_DB_HOST=user_db  # Docker container name
MATCHING_REDIS_HOST=matching_redis
```

**Production:**
```bash
USER_DB_HOST=peerprep-db.xxxxxx.us-east-1.rds.amazonaws.com
MATCHING_REDIS_HOST=peerprep-redis.xxxxxx.ng.0001.use1.cache.amazonaws.com
```

---

## 🚀 Deployment Workflow

### Local Development
```bash
# 1. Use .env (already configured)
docker-compose up

# Access: http://localhost:5173/
```

### Production (ECS)
```bash
# 1. Copy production template
cp .env.prod.sample .env.prod

# 2. Edit .env.prod with real values
vim .env.prod

# 3. Deploy using AWS tooling
docker-compose --env-file .env.prod -f docker-compose.prod.yml up

# OR store in AWS Secrets Manager and inject at runtime
```

---

## ✅ What Changed from Original

### Before:
```
.env.sample             (outdated variable names)
.env.production.sample  (inconsistent naming)
.env.prod.sample        (outdated)
```

### After:
```
.env.sample             ✅ Updated with hyphenated services + nginx config
.env.prod.sample        ✅ Updated with ECS service discovery
```

### Removed:
```
.env.production.sample  ❌ Deleted (use .env.prod.sample instead)
```

---

## 📝 Checklist for New Team Members

**First Time Setup:**

- [ ] Clone repository
- [ ] Copy `.env.sample` to `.env`
  ```bash
  cp .env.sample .env
  ```
- [ ] Create shared Docker network
  ```bash
  docker network create peerprep_shared_network
  ```
- [ ] Start services
  ```bash
  docker-compose up
  ```
- [ ] Access application at http://localhost:5173/

**Before Production Deployment:**

- [ ] Copy `.env.prod.sample` to `.env.prod`
- [ ] Replace all `CHANGEME_*` values
- [ ] Update AWS endpoints (RDS, ElastiCache)
- [ ] Generate Django SECRET_KEY
- [ ] Update ALLOWED_HOSTS with domain
- [ ] Store `.env.prod` in AWS Secrets Manager
- [ ] Never commit `.env.prod` to git

---

## 🛡️ .gitignore

Ensure these lines exist in `.gitignore`:

```gitignore
# Environment files with secrets
.env
.env.prod
.env.local
.env.*.local

# Allow templates
!.env.sample
!.env.prod.sample
```

---

**Last Updated:** 2025-10-08
**Version:** 2.0 (Post nginx implementation)
