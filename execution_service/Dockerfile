FROM python:3.10-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Set work directory
WORKDIR /app

# Install AWS CLI and system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        unzip \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY . .

# Add entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Use environment variable for port (default to 8000)
ENV PORT=8000
EXPOSE $PORT

# Set entrypoint and default command
ENTRYPOINT ["docker-entrypoint.sh"]
CMD sh -c "python manage.py runserver 0.0.0.0:${PORT}"


