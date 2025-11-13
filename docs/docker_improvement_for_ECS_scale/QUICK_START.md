# PeerPrep - Quick Start Guide

## ✅ Implementation Complete!

All Docker configurations have been updated for service discovery and nginx proxying.

---

## 🚀 Start All Services

```bash
# From project root
docker-compose up
```

Access the application:
- **Frontend**: http://localhost/
- **Health check**: http://localhost/health
- **API Example**: http://localhost/user-service-api/health

---

## 📋 What Changed

### Service Naming
- ✅ All services use hyphenated names: `user-service`, `question-service`, etc.
- ✅ Docker DNS works: Services can call `http://user-service:8000`

### Port Standardization
- ✅ All backend services expose **port 8000** internally
- ✅ External mapping preserved: 8001, 8002, 8003, etc. (for development)

### Nginx Frontend
- ✅ Frontend now runs **nginx** (not Vite dev server) in Docker
- ✅ Single entry point on **port 80**
- ✅ Proxies all API calls to backend services

### Request Flow

**Browser → Nginx → Backend Services**

```
Browser:  http://localhost/user-service-api/login
          ↓
Nginx:    Strips /user-service-api prefix
          ↓
Backend:  http://user-service:8000/login
```

---

## 🛠️ Development Workflows

### Option 1: Full Docker Stack (Recommended)
```bash
# Start everything
docker-compose up

# Access frontend
open http://localhost/

# Frontend makes API calls like:
# /user-service-api/login → user-service:8000/login
```

### Option 2: Frontend Outside Docker (Hot Reload)
```bash
# Start backend services only
docker-compose up user-service question-service matching-service

# In another terminal, run frontend locally
cd frontend
npm run dev

# Access frontend at http://localhost:5173
# Configure vite.config.js proxy if needed
```

---

## ⚠️ Code Changes Required

**See `MIGRATION_GUIDE.md` for detailed instructions**

### Quick Summary:

#### 1. Collaboration Service (Port Change)
```javascript
// BEFORE
const PORT = 8005;

// AFTER
const PORT = process.env.PORT || 8000;
```

#### 2. Chat Service (Port Change)
```javascript
// BEFORE
const PORT = 8006;

// AFTER
const PORT = process.env.PORT || 8000;
```

#### 3. All Services (Use Environment Variables)
```python
# Python/Django example
QUESTION_SERVICE_URL = os.environ.get('QUESTION_SERVICE_URL', 'http://question-service:8000')

# Then use it:
response = requests.get(f"{QUESTION_SERVICE_URL}/api/questions")
```

```javascript
// Node.js example
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://user-service:8000';

// Then use it:
const response = await axios.get(`${USER_SERVICE_URL}/api/users`);
```

---

## 🧪 Testing

### Test Nginx Health
```bash
curl http://localhost/health
# Should return: healthy
```

### Test API Proxying
```bash
# Start user service first
docker-compose up user-service

# Test proxy (from host machine)
curl http://localhost/user-service-api/health
# Should proxy to user-service:8000/health
```

### Test Service Discovery
```bash
# From inside a container
docker exec -it peerprep_user_service curl http://question-service:8000/health

# Should work if question-service is running
```

---

## 📁 File Structure

```
project/
├── docker-compose.yml              # Master orchestration (updated)
├── .env                            # Development config (updated)
├── .env.prod                       # Production config (NEW)
│
├── frontend/
│   ├── Dockerfile                  # Multi-stage build (updated)
│   ├── docker-compose.yml          # Nginx config (updated)
│   └── nginx.conf.template         # Proxy rules (NEW)
│
├── user_service/
│   └── docker-compose.yml          # Service name: user-service (updated)
│
├── question_service/
│   └── docker-compose.yml          # Service name: question-service (updated)
│
└── docs/docker_improvement_for_ECS_scale/
    ├── IMPLEMENTATION_PLAN.md      # Full architecture plan
    ├── MIGRATION_GUIDE.md          # Code changes needed
    └── QUICK_START.md              # This file
```

---

## 🐛 Troubleshooting

### Issue: "host not found in upstream user-service"

**Cause**: Backend services aren't running when nginx starts

**Solution**: Start all services together
```bash
docker-compose down
docker-compose up  # This starts backends first, then frontend
```

### Issue: Port already in use

**Cause**: Old containers still running

**Solution**:
```bash
docker-compose down --remove-orphans
docker ps -a  # Check for any remaining containers
docker rm -f $(docker ps -aq)  # Remove all if needed
```

### Issue: Frontend can't reach backend

**Cause**: Services not on shared network

**Solution**:
```bash
# Create shared network if it doesn't exist
docker network create peerprep_shared_network

# Restart services
docker-compose down
docker-compose up
```

---

## 🎯 Next Steps

1. **Test Locally**
   ```bash
   docker-compose up
   open http://localhost/
   ```

2. **Make Code Changes** (see MIGRATION_GUIDE.md)
   - Update collaboration service port
   - Update chat service port
   - Add service URL environment variables

3. **Production Deployment**
   - Update `.env.prod` with real AWS endpoints
   - Configure ECS service discovery
   - Deploy to ECS

---

## 📚 Documentation

- **IMPLEMENTATION_PLAN.md** - Complete architecture and design
- **MIGRATION_GUIDE.md** - Code changes required
- **nginx_redirecting** - Original nginx configuration notes

---

**Ready to go!** 🎉

Run `docker-compose up` and access http://localhost/
