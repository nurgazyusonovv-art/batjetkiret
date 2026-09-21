web: alembic upgrade head && gunicorn app.main:app --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT --workers ${WEB_CONCURRENCY:-1} --timeout 120 --keep-alive 75
