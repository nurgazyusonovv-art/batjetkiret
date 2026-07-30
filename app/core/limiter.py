"""Rate limiter configuration for the application."""
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.core.config import settings

# Use Redis as shared storage when REDIS_URL is set so limits are enforced
# consistently across multiple gunicorn workers. Falls back to in-memory
# (per-process) storage for local/dev or single-worker deployments.
_storage_uri = settings.REDIS_URL or "memory://"

limiter = Limiter(key_func=get_remote_address, storage_uri=_storage_uri)
