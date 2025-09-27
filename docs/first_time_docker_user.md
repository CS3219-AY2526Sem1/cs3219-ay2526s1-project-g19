Quick Start
# 1. Clone and enter project
git clone <repo-url>
cd cs3219-project

# 2. Start Docker Desktop
open -a Docker

# 3. Copy environment file
cp .env.sample .env

# 4. Run everything

## Build 
docker-compose up --build

## Access Your Services

Frontend: http://localhost:5173
Question API: http://localhost:8001
Matching API: http://localhost:8002
Collaboration API: http://localhost:8003

## Daily Development

### Start services:
docker-compose up -d
### Stop services:
docker-compose down
### View logs:
docker-compose logs -f
### Clean restart:
docker-compose down -v
docker-compose up --build


## Working on Specific Services
### Frontend developer (fastest):
cd frontend
npm run dev

###  Backend developer: Only restart your service
docker-compose up question_service --build

# Troubleshooting

## Check what's running
docker ps

## Clean everything
docker system prune -f
docker-compose down -v
docker-compose up --build

That's it. Start with the Quick Start section, then use Daily Development commands.Retry

# 26 Seept
Kim updated a few more things
1. entrypoints.sh for docker to initialise db up before local run.
2. updated Dockerfile with entrypoints, create static files, variable based on env #forseee future got permission error need settle oso.
3. update requirements.txt for rest framework, and also db_url reading, cors.
4. update settings.py for more statics file/logging/restframework also installed app, importantly for database... previously forgot setup haha. #haven't check if actually using psqlite or db in docker... should be ah should be...

created new file for how+kim_initialise user services.