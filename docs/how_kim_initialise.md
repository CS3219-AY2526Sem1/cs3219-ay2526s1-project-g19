
Backend : Python3.10 + Django

Why Django (admin interface, django rest framework)
Frontend : Node.js + Vite + tailwindcss


# Setting up for services
1. UI
2. python backend services : (question, collaboration, matching) , potential another for code evaluation engine service
3. node.js backend service : (user service) -- dont rebuild the wheel


# setup a python environment
- python3.10 -m venv venv
- source venv/bin/activate
- python3.10 -m pip install django
- pip3.10 freeze > requirements.txt
- pip3.10 install -r requirements.txt

creating python backend services
`
mkdir question_service
django-admin startproject question_service .

mkdir matching_service & cd matching_service
django-admin startproject matching_service .

mkdir collaboration_service
django-admin startproject collaboration_service .
`


# Create the frontend project
npm create vite@latest frontend -- --template react
cd frontend
npm install

# Create docker folders for these services
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8001
CMD ["python", "manage.py", "runserver", "0.0.0.0:8001"]

# Create docker folders for these services
FROM python:3.10-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8001
CMD ["python", "manage.py", "runserver", "0.0.0.0:8001"]

# Docker setup completed

Created Dockerfiles for each Python service (question_service, matching_service, collaboration_service) with ports 8001, 8002, 8003
Created frontend Dockerfile with Node.js 22 and port 5173
Setup docker-compose.yml with all services + separate PostgreSQL databases
Created docker-compose.prod.yml for production overrides
Setup environment management with .env, .env.local, .env.production
Each service gets its own database: question_db, matching_db, collaboration_db
Production setup allows switching to external managed databases via DATABASE_URL overrides

# File structure created
cs3219-project/
├── .env                          # Base config (POSTGRES_USER=postgres, DEBUG=True, ports 5173,8001-8003)
├── .env.production              # Prod config (DEBUG=False, external DATABASE_URLs, secure keys)
├── docker-compose.yml           # Base services + 3 postgres containers + volume mounts
├── docker-compose.prod.yml      # Production overrides (disable DB containers, restart policies)
├── question_service/
│   └── Dockerfile              # Python 3.10, port 8001, django runserver
├── matching_service/
│   └── Dockerfile              # Python 3.10, port 8002, django runserver  
├── collaboration_service/
│   └── Dockerfile              # Python 3.10, port 8003, django runserver
└── frontend/
    └── Dockerfile              # Node.js 22, port 5173, vite dev server