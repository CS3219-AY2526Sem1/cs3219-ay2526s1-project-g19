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

# Copy package files and install ALL dependencies (including devDependencies for build)
COPY package*.json ./
RUN npm ci && npm cache clean --force

# Copy application files
COPY . .

# Accept build arguments for Vite environment variables
# These are embedded into the JS bundle at build time
ARG VITE_QUESTION_SERVICE_URL
ARG VITE_MATCHING_SERVICE_URL
ARG VITE_HISTORY_SERVICE_URL
ARG VITE_USER_SERVICE_URL
ARG VITE_SESSION_SERVICE_URL
ARG VITE_COLLABORATION_SERVICE_URL
ARG VITE_CHAT_SERVICE_URL
ARG VITE_EXECUTION_API

# Set as environment variables for the build process
ENV VITE_QUESTION_SERVICE_URL=${VITE_QUESTION_SERVICE_URL}
ENV VITE_MATCHING_SERVICE_URL=${VITE_MATCHING_SERVICE_URL}
ENV VITE_HISTORY_SERVICE_URL=${VITE_HISTORY_SERVICE_URL}
ENV VITE_USER_SERVICE_URL=${VITE_USER_SERVICE_URL}
ENV VITE_SESSION_SERVICE_URL=${VITE_SESSION_SERVICE_URL}
ENV VITE_COLLABORATION_SERVICE_URL=${VITE_COLLABORATION_SERVICE_URL}
ENV VITE_CHAT_SERVICE_URL=${VITE_CHAT_SERVICE_URL}
ENV VITE_EXECUTION_API=${VITE_EXECUTION_API}

# Build the application (requires devDependencies like vite, rolldown, etc.)
RUN npm run build

# =============================================================================
# Stage 3: Production (Nginx + Static Files)
# =============================================================================
FROM nginx:alpine AS production

# Tooling needed for startup templating
RUN apk add --no-cache gettext python3

# Remove default nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy nginx template configuration
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Copy built static files from build stage
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["/docker-entrypoint.sh"]
