FROM python:3.10-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY . .

# Use environment variable for port (default to 8000)
ENV PORT=8000
EXPOSE $PORT

# Run Django server
CMD sh -c "python manage.py migrate --noinput && python manage.py runserver 0.0.0.0:${PORT}"


