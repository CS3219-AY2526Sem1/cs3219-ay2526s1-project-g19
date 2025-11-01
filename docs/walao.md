# Complete Flow: From User Request to Auto-Scaling with GitHub Actions CI/CD

Let me walk you through the entire journey - from a user clicking a button to auto-scaling and deployment with GitHub Actions.

-----

## 🌊 **PART 1: Request Flow (Production Runtime)**

### **Scenario: User wants to get their profile**

```
User clicks "My Profile" button in React app
```

-----

### **Step 1: Frontend Makes API Call**

```javascript
// React app running in user's browser
const getProfile = async () => {
  const response = await fetch('https://peerprep.com/user-service-api/users/123', {
    headers: {
      'Authorization': 'Bearer jwt-token-here'
    }
  });
  return response.json();
};
```

-----

### **Step 2: DNS Resolution**

```
Browser: "Where is peerprep.com?"
    ↓
DNS Server: "It's at 54.123.45.67" (ALB's public IP)
    ↓
HTTPS request sent to: 54.123.45.67:443
```

-----

### **Step 3: Request Hits ALB (Application Load Balancer)**

```
┌─────────────────────────────────────────────────────┐
│ ALB (Public Subnet - Internet-facing)               │
│ IP: 54.123.45.67                                    │
└─────────────────────────────────────────────────────┘
         ↓
Request: GET /user-service-api/users/123
         ↓
ALB examines path and applies listener rules
```

### **ALB Listener Rules (Priority-based matching)**

```
┌──────────────────────────────────────────────────────┐
│ ALB Listener Rules (Port 443 - HTTPS)               │
├──────────────────────────────────────────────────────┤
│                                                      │
│ Priority 1: Path = "/user-service-api/*"            │
│    ✅ MATCH! → Forward to user-service Target Group │
│                                                      │
│ Priority 2: Path = "/question-service-api/*"        │
│    ❌ No match                                       │
│                                                      │
│ Priority 3: Path = "/matching-service-api/*"        │
│    ❌ No match                                       │
│                                                      │
│ Priority 100: Path = "/*" (Default)                 │
│    → Forward to frontend Target Group               │
└──────────────────────────────────────────────────────┘
```

**What happens:**

```python
# Pseudocode of ALB logic
def route_request(path):
    if path.startswith("/user-service-api/"):
        return user_service_target_group
    elif path.startswith("/question-service-api/"):
        return question_service_target_group
    # ... other rules
    else:
        return frontend_target_group  # Default
```

-----

### **Step 4: Target Group Selection**

```
ALB selected: user-service Target Group
    ↓
Target Group contains healthy targets (ECS tasks)
    ↓
┌─────────────────────────────────────────────┐
│ user-service Target Group                   │
├─────────────────────────────────────────────┤
│ Target 1: 10.0.3.45:8000 ✅ healthy         │
│ Target 2: 10.0.3.89:8000 ✅ healthy         │
│ Target 3: 10.0.3.112:8000 ❌ unhealthy      │
└─────────────────────────────────────────────┘
```

**Health Check Logic:**

```
Every 30 seconds, ALB checks each target:

GET http://10.0.3.45:8000/health
    ↓
Response: 200 OK
    ↓
Healthy count++

If 2 consecutive checks pass → Mark HEALTHY ✅
If 3 consecutive checks fail → Mark UNHEALTHY ❌
```

-----

### **Step 5: ALB Picks a Target (Load Balancing)**

```
ALB uses Round Robin algorithm:

Request 1 → Target 1 (10.0.3.45)
Request 2 → Target 2 (10.0.3.89)
Request 3 → Target 1 (10.0.3.45)
Request 4 → Target 2 (10.0.3.89)
...

Note: Target 3 is unhealthy, so it's skipped!
```

**For this request:**

```
ALB chooses: Target 1 (10.0.3.45:8000)
    ↓
Forwards request to private IP in VPC
```

-----

### **Step 6: Request Enters Private Subnet**

```
┌──────────────────────────────────────────────────────┐
│ Private Subnet (10.0.3.0/24)                         │
│                                                      │
│  ┌────────────────────────────────────┐            │
│  │ ECS Fargate Task                   │            │
│  │ Private IP: 10.0.3.45              │            │
│  │ ┌────────────────────────────────┐ │            │
│  │ │ Container: user-service        │ │            │
│  │ │ Port: 8000                     │ │            │
│  │ │ Image: user-service:abc123     │ │            │
│  │ └────────────────────────────────┘ │            │
│  └────────────────────────────────────┘            │
└──────────────────────────────────────────────────────┘
         ↓
Request arrives: GET /users/123
```

**Security Group Check:**

```
┌──────────────────────────────────────────┐
│ ECS Task Security Group                  │
├──────────────────────────────────────────┤
│ Inbound Rule:                            │
│ └─ Allow TCP 8000 from ALB Security Group │
│                                          │
│ Request from: ALB (sg-alb123)            │
│ Destination: Port 8000 ✅ ALLOWED        │
└──────────────────────────────────────────┘
```

-----

### **Step 7: Django Application Processes Request**

```python
# Inside user_service container (Django)

# 1. Nginx receives request (if using nginx)
# 2. Passes to Gunicorn/Uvicorn
# 3. Django view handles it

# user_service/views.py
from rest_framework.decorators import api_view

@api_view(['GET'])
def get_user(request, user_id):
    # Verify JWT token
    token = request.headers.get('Authorization')
    user = authenticate_jwt(token)
    
    # Query database
    db_user = User.objects.get(id=user_id)
    
    # Return response
    return Response({
        'id': db_user.id,
        'name': db_user.name,
        'email': db_user.email
    })
```

**Database Query:**

```
Django ORM → PostgreSQL query
    ↓
┌──────────────────────────────────────────┐
│ RDS PostgreSQL (user_db)                │
│ Endpoint: user-db.xyz.rds.amazonaws.com │
│ Private IP: 10.0.5.20:5432              │
└──────────────────────────────────────────┘

SQL: SELECT * FROM users WHERE id = 123;
    ↓
Returns user data
```

-----

### **Step 8: Service-to-Service Call (Service Discovery)**

**Scenario: user-service needs to call history-service**

```python
# user_service wants to get user's history

# ❌ BAD: Hardcoded IP
response = requests.get('http://10.0.3.67:8000/api/history/user/123')
# Problem: IP changes when task restarts!

# ✅ GOOD: Use Service Discovery
response = requests.get('http://history-service.peerprep-prod.local:8000/api/history/user/123')
# Service Discovery resolves this dynamically!
```

**Service Discovery Resolution:**

```
Step 1: user-service makes DNS query
    ↓
Query: history-service.peerprep-prod.local
    ↓
VPC DNS Resolver forwards to Cloud Map
    ↓
┌──────────────────────────────────────────────┐
│ AWS Cloud Map (Service Discovery)           │
├──────────────────────────────────────────────┤
│ Service: history-service                     │
│ Namespace: peerprep-prod.local               │
│                                              │
│ Registered Instances:                        │
│ ├─ Task 1: 10.0.3.67:8000 ✅ healthy        │
│ └─ Task 2: 10.0.3.91:8000 ✅ healthy        │
└──────────────────────────────────────────────┘
    ↓
Returns: [10.0.3.67, 10.0.3.91]
    ↓
user-service picks one: 10.0.3.67
    ↓
Direct container-to-container HTTP call
    ↓
No ALB involved! Private network only
```

**Visual:**

```
┌─────────────────┐         Private Network         ┌─────────────────┐
│  user-service   │  ←─────────────────────────→   │ history-service │
│  10.0.3.45:8000 │    Direct HTTP connection      │  10.0.3.67:8000 │
└─────────────────┘                                 └─────────────────┘
```

-----

### **Step 9: Response Returns to User**

```
history-service responds
    ↓
user-service aggregates data
    ↓
user-service returns JSON response
    ↓
Response goes back through ALB
    ↓
ALB forwards to user's browser
    ↓
React app updates UI
```

-----

## 📊 **PART 2: Auto-Scaling (Load Detection)**

### **CloudWatch Monitors Metrics**

```
Every 60 seconds, CloudWatch collects:
├─ CPU Utilization (%)
├─ Memory Utilization (%)
├─ ALB Request Count
└─ ALB Response Time (ms)
```

**Example metrics:**

```
Time: 14:00:00
├─ user-service CPU: 45%
├─ user-service Memory: 60%
├─ ALB requests to user-service: 100/min
└─ Response time: 200ms

Time: 14:05:00
├─ user-service CPU: 85% 🚨 HIGH!
├─ user-service Memory: 80% 🚨 HIGH!
├─ ALB requests to user-service: 500/min
└─ Response time: 800ms 🚨 SLOW!
```

-----

### **Auto-Scaling Policy Triggered**

```
┌──────────────────────────────────────────────────┐
│ ECS Auto Scaling Policy                          │
├──────────────────────────────────────────────────┤
│ Target Metric: CPU Utilization                   │
│ Target Value: 70%                                │
│ Current Value: 85% ❗                            │
│                                                  │
│ 85% > 70% → SCALE OUT! Add more tasks           │
└──────────────────────────────────────────────────┘
```

**Scaling Decision:**

```python
# Pseudocode of auto-scaling logic
if current_cpu > target_cpu:
    desired_tasks = ceil(current_tasks * (current_cpu / target_cpu))
    scale_to(desired_tasks)

# Example:
current_tasks = 2
current_cpu = 85%
target_cpu = 70%

desired_tasks = ceil(2 * (85 / 70)) = ceil(2.43) = 3

Action: Scale from 2 tasks to 3 tasks
```

-----

### **New Task Spins Up**

```
Step 1: ECS decides to launch new task
    ↓
┌──────────────────────────────────────────────────┐
│ ECS Control Plane                                │
├──────────────────────────────────────────────────┤
│ Task Definition: user-service:v1.2.3             │
│ Desired Count: 2 → 3                             │
│ Action: Launch 1 new task                        │
└──────────────────────────────────────────────────┘
    ↓
Step 2: Find capacity in Fargate
    ↓
Step 3: Allocate resources
    ├─ CPU: 512 (0.5 vCPU)
    ├─ Memory: 1024 MB (1 GB)
    └─ Network: Private subnet 10.0.3.0/24
    ↓
Step 4: Assign private IP: 10.0.3.115
```

-----

### **Task Startup Sequence**

```
┌────────────────────────────────────────────────────┐
│ Task 3 Startup (10.0.3.115)                        │
├────────────────────────────────────────────────────┤
│ 1. Pull image from ECR                             │
│    └─ Download: user-service:abc123 (150 MB)       │
│                                                    │
│ 2. Fetch secrets from AWS Secrets Manager         │
│    ├─ SECRET_KEY                                   │
│    ├─ DB_PASSWORD                                  │
│    └─ JWT_SECRET_KEY                               │
│                                                    │
│ 3. Start container                                 │
│    └─ docker run user-service:abc123               │
│                                                    │
│ 4. Run entrypoint script                           │
│    ├─ Wait for database (netcat check)            │
│    ├─ Run migrations: python manage.py migrate    │
│    └─ Start server: python manage.py runserver    │
│                                                    │
│ 5. Application starts listening on port 8000      │
└────────────────────────────────────────────────────┘
```

**Entrypoint Script:**

```bash
#!/bin/bash
# docker-entrypoint.sh

# Wait for database to be ready
until nc -z user-db.xyz.rds.amazonaws.com 5432; do
  echo "Waiting for database..."
  sleep 2
done

# Run migrations
python manage.py migrate --noinput

# Start application
exec python manage.py runserver 0.0.0.0:8000
```

-----

### **Health Checks Begin**

```
┌────────────────────────────────────────────────────┐
│ Health Check 1: ECS Task Health Check             │
├────────────────────────────────────────────────────┤
│ Command: curl -f http://localhost:8000/health     │
│ Interval: 30 seconds                               │
│ Timeout: 5 seconds                                 │
│ Retries: 3                                         │
│ Start Period: 60 seconds (grace period)            │
│                                                    │
│ Attempt 1 (t=60s): Success ✅                      │
│ Attempt 2 (t=90s): Success ✅                      │
│ Attempt 3 (t=120s): Success ✅                     │
│                                                    │
│ Status: HEALTHY ✅                                 │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ Health Check 2: ALB Target Group Health Check     │
├────────────────────────────────────────────────────┤
│ URL: GET http://10.0.3.115:8000/health            │
│ Interval: 30 seconds                               │
│ Timeout: 5 seconds                                 │
│ Healthy Threshold: 2 consecutive successes         │
│ Unhealthy Threshold: 3 consecutive failures        │
│                                                    │
│ Attempt 1 (t=30s): 200 OK ✅                       │
│ Attempt 2 (t=60s): 200 OK ✅                       │
│                                                    │
│ Status: HEALTHY ✅ → Added to Target Group         │
└────────────────────────────────────────────────────┘
```

-----

### **Service Discovery Registration**

```
┌────────────────────────────────────────────────────┐
│ AWS Cloud Map Registration                        │
├────────────────────────────────────────────────────┤
│ Service: user-service                              │
│ Namespace: peerprep-prod.local                     │
│                                                    │
│ New Instance Registered:                           │
│ ├─ Instance ID: task-xyz789                        │
│ ├─ IP Address: 10.0.3.115                          │
│ ├─ Port: 8000                                      │
│ └─ Health Status: HEALTHY ✅                       │
│                                                    │
│ DNS Record Updated:                                │
│ user-service.peerprep-prod.local                   │
│ ├─ A record: 10.0.3.45                             │
│ ├─ A record: 10.0.3.89                             │
│ └─ A record: 10.0.3.115 ← NEW!                     │
└────────────────────────────────────────────────────┘
```

-----

### **ALB Adds New Target**

```
Before scaling:
┌─────────────────────────────────────┐
│ user-service Target Group           │
├─────────────────────────────────────┤
│ Target 1: 10.0.3.45 ✅ 50% traffic  │
│ Target 2: 10.0.3.89 ✅ 50% traffic  │
└─────────────────────────────────────┘

After scaling:
┌─────────────────────────────────────┐
│ user-service Target Group           │
├─────────────────────────────────────┤
│ Target 1: 10.0.3.45 ✅ 33% traffic  │
│ Target 2: 10.0.3.89 ✅ 33% traffic  │
│ Target 3: 10.0.3.115 ✅ 33% traffic │
└─────────────────────────────────────┘

Load is now distributed across 3 tasks!
CPU drops from 85% to ~60% per task
```

-----

### **What About Redis/ElastiCache?**

**Redis does NOT auto-scale with tasks** - here’s why:

```
Scenario: matching-service scales from 2 to 3 tasks

┌──────────────────────────────────────────────────┐
│ matching-service (3 tasks)                       │
│ ├─ Task 1: 10.0.3.45                             │
│ ├─ Task 2: 10.0.3.89                             │
│ └─ Task 3: 10.0.3.115                            │
│                                                  │
│ All 3 tasks connect to SAME Redis cluster       │
│         ↓         ↓         ↓                    │
│    ┌────────────────────────────┐               │
│    │ ElastiCache Redis Cluster  │               │
│    │ matching.xyz.cache.aws.com │               │
│    │                            │               │
│    │ Does NOT scale with tasks  │               │
│    │ (Separate resource)        │               │
│    └────────────────────────────┘               │
└──────────────────────────────────────────────────┘
```

**Redis/ElastiCache Scaling:**

- **ECS tasks** scale based on CPU/memory/requests
- **Redis** scales separately based on:
  - Memory usage
  - CPU usage
  - Number of connections
  - Evictions (when memory full)

```
If Redis needs scaling:
├─ Manual: Change node type (e.g., cache.t3.micro → cache.t3.medium)
├─ Or: Enable cluster mode and add more shards
└─ This is infrastructure change, not task scaling
```

-----

## 🚀 **PART 3: CI/CD with GitHub Actions**

### **Deployment Trigger**

```
Developer workflow:
├─ Write code
├─ Commit: git commit -m "feat: improve user API"
├─ Push: git push origin feature/user-api
├─ Open PR to main
├─ CI runs (tests, lint)
├─ PR approved & merged
├─ Auto-merge to staging
├─ Staging deployment
├─ QA testing
├─ Merge to prod/ecs-prod ← PRODUCTION DEPLOYMENT TRIGGERED
```

-----

### **GitHub Actions Workflow Execution**

```yaml
# .github/workflows/deploy-production.yml

name: Deploy to Production

on:
  push:
    branches: [prod/ecs-prod]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Requires approval
    steps:
      # ... (shown earlier)
```

**Visual Flow:**

```
Push to prod/ecs-prod
    ↓
GitHub Actions Server starts job
    ↓
┌──────────────────────────────────────────────┐
│ GitHub Actions Runner (Ubuntu VM)            │
│                                              │
│ Job: deploy-production                       │
│ Commit: abc123f                              │
│ Actor: john-doe                              │
└──────────────────────────────────────────────┘
```

-----

### **Step-by-Step GitHub Actions Execution**

#### **Step 1: Build Images**

```
┌────────────────────────────────────────────────┐
│ Step: Build user-service                       │
├────────────────────────────────────────────────┤
│ $ docker build --platform linux/amd64 \        │
│     -t user-service:abc123 ./user_service      │
│                                                │
│ [1/8] FROM python:3.10-slim                    │
│ [2/8] WORKDIR /app                             │
│ [3/8] COPY requirements.txt .                  │
│ [4/8] RUN pip install -r requirements.txt      │
│ [5/8] COPY . .                                 │
│ [6/8] RUN mkdir -p /app/staticfiles            │
│ [7/8] COPY docker-entrypoint.sh ...            │
│ [8/8] CMD ["python", "manage.py", "runserver"] │
│                                                │
│ ✅ Successfully built user-service:abc123      │
└────────────────────────────────────────────────┘
```

**Parallel builds (7 services at once):**

```
GitHub Actions Matrix Strategy:
├─ Job 1: Build user-service ✅ (2 min)
├─ Job 2: Build question-service ✅ (2 min)
├─ Job 3: Build matching-service ✅ (2 min)
├─ Job 4: Build history-service ✅ (2 min)
├─ Job 5: Build collaboration-service ✅ (2 min)
├─ Job 6: Build chat-service ✅ (2 min)
└─ Job 7: Build frontend ✅ (3 min)

Total time: 3 minutes (not 15 minutes sequential!)
```

-----

#### **Step 2: Push to ECR**

```
┌────────────────────────────────────────────────┐
│ Step: Push to ECR                              │
├────────────────────────────────────────────────┤
│ $ aws ecr get-login-password | docker login    │
│ Login Succeeded                                │
│                                                │
│ $ docker tag user-service:abc123 \             │
│     123456.dkr.ecr.us-east-1.amazonaws.com/... │
│                                                │
│ $ docker push 123456.dkr.ecr.../user-service  │
│                                                │
│ abc123: Pushing [========>              ] 45%  │
│ abc123: Pushing [================>      ] 78%  │
│ abc123: Pushed                          ✅     │
│                                                │
│ Image available in ECR!                        │
└────────────────────────────────────────────────┘
```

-----

#### **Step 3: Deploy to ECS**

```
┌────────────────────────────────────────────────┐
│ Step: Update ECS Service                       │
├────────────────────────────────────────────────┤
│ $ aws ecs update-service \                     │
│     --cluster peerprep-prod-cluster \          │
│     --service peerprep-prod-user-service \     │
│     --force-new-deployment                     │
│                                                │
│ {                                              │
│   "service": {                                 │
│     "serviceName": "peerprep-prod-user-service"│
│     "status": "ACTIVE",                        │
│     "desiredCount": 2,                         │
│     "runningCount": 2,                         │
│     "deployments": [                           │
│       {                                        │
│         "id": "ecs-svc/1234567890",            │
│         "status": "PRIMARY",                   │
│         "taskDefinition": "...:42",            │
│         "desiredCount": 2,                     │
│         "runningCount": 2,                     │
│         "rolloutState": "IN_PROGRESS" ⏳       │
│       }                                        │
│     ]                                          │
│   }                                            │
│ }                                              │
└────────────────────────────────────────────────┘
```

-----

#### **Step 4: Rolling Update (Inside ECS)**

```
Current State: 2 tasks running (old version)
┌────────────────┐  ┌────────────────┐
│ Task 1 (old)   │  │ Task 2 (old)   │
│ 10.0.3.45:8000 │  │ 10.0.3.89:8000 │
└────────────────┘  └────────────────┘

Rolling Update Begins:
    ↓
Step 1: Start new tasks (max 200% = 4 total)
┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│ Task 1 (old)   │  │ Task 2 (old)   │  │ Task 3 (NEW)   │  │ Task 4 (NEW)   │
│ 10.0.3.45      │  │ 10.0.3.89      │  │ 10.0.3.115     │  │ 10.0.3.122     │
│ ✅ HEALTHY     │  │ ✅ HEALTHY     │  │ ⏳ STARTING    │  │ ⏳ STARTING    │
└────────────────┘  └────────────────┘  └────────────────┘  └────────────────┘
    ↓
Step 2: Wait for new tasks to pass health checks
┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│ Task 1 (old)   │  │ Task 2 (old)   │  │ Task 3 (NEW)   │  │ Task 4 (NEW)   │
│ ✅ HEALTHY     │  │ ✅ HEALTHY     │  │ ✅ HEALTHY     │  │ ✅ HEALTHY     │
└────────────────┘  └────────────────┘  └────────────────┘  └────────────────┘
    ↓
Step 3: ALB adds new tasks to Target Group
ALB Traffic: 25% each to all 4 tasks
    ↓
Step 4: Drain old tasks (stop new connections)
┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│ Task 1 (old)   │  │ Task 2 (old)   │  │ Task 3 (NEW)   │  │ Task 4 (NEW)   │
│ 🔄 DRAINING    │  │ 🔄 DRAINING    │  │ ✅ HEALTHY     │  │ ✅ HEALTHY     │
│ (finishing     │  │ (finishing     │  │ (receiving     │  │ (receiving     │
│  requests)     │  │  requests)     │  │  new traffic)  │  │  new traffic)  │
└────────────────┘  └────────────────┘  └────────────────┘  └────────────────┘
    ↓
Wait 300 seconds (deregistration delay) for connections to finish
    ↓
Step 5: Stop old tasks
┌────────────────┐  ┌────────────────┐
│ Task 3 (NEW)   │  │ Task 4 (NEW)   │
│ ✅ HEALTHY     │  │ ✅ HEALTHY     │
└────────────────┘  └────────────────┘

Final State: 2 new tasks running
Zero downtime achieved! ✅
```

-----

#### **Step 5: Wait for Stability**

```
┌────────────────────────────────────────────────┐
│ Step: Wait for services to stabilize           │
├────────────────────────────────────────────────┤
│ $ aws ecs wait services-stable \               │
│     --cluster peerprep-prod-cluster \          │
│     --services peerprep-prod-user-service      │
│                                                │
│ ⏳ Waiting for deployment to complete...       │
│                                                │
│ Checking deployment status:                    │
│ ├─ Running tasks: 2 / 2 ✅                     │
│ ├─ Health checks: Passing ✅                   │
│ ├─ ALB targets: Healthy ✅                     │
│ └─ Deployment status: COMPLETED ✅             │
│                                                │
│ ✅ Service is stable!                          │
│ Deployment took: 4 minutes 32 seconds          │
└────────────────────────────────────────────────┘
```

-----

#### **Step 6: Health Check Verification**

```
┌────────────────────────────────────────────────┐
│ Step: Verify health endpoints                  │
├────────────────────────────────────────────────┤
│ ALB_URL=peerprep-prod-alb.us-east-1.elb...     │
│                                                │
│ Testing: https://$ALB_URL/                     │
│ Response: 200 OK ✅                            │
│                                                │
│ Testing: /user-service-api/health              │
│ Response: 200 OK ✅                            │
│ Body: {"status":"healthy","database":"ok"}     │
│
```