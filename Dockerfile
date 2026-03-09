FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Run migrations on startup
RUN echo '#!/bin/bash\nalembic upgrade head\ngunicorn app.main:app --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:${PORT:-8000}' > /app/start.sh
RUN chmod +x /app/start.sh

# Expose port
EXPOSE 8000

# Start application
CMD ["/app/start.sh"]
