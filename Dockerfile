FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p uploads/screenshots

EXPOSE 8000

# Run migrations, but never let a migration failure block the app from starting
# (the schema is already in place; a failed migration must not take the API down).
CMD (alembic upgrade head || echo "⚠️  alembic upgrade failed — starting app anyway"); \
    gunicorn app.main:app \
        --worker-class uvicorn.workers.UvicornWorker \
        --bind 0.0.0.0:${PORT:-8000} \
        --workers ${WEB_CONCURRENCY:-1} \
        --timeout 120 \
        --keep-alive 75
