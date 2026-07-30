"""Cloudflare R2 object storage helpers."""
import mimetypes

import boto3
from botocore.config import Config
from fastapi import HTTPException

from app.core.config import settings


def _require_r2_settings() -> None:
    missing = [
        name
        for name, value in {
            "R2_ACCESS_KEY": settings.R2_ACCESS_KEY,
            "R2_SECRET_KEY": settings.R2_SECRET_KEY,
            "R2_ENDPOINT": settings.R2_ENDPOINT,
            "R2_BUCKET": settings.R2_BUCKET,
            "R2_PUBLIC_BASE": settings.R2_PUBLIC_BASE,
        }.items()
        if not value
    ]
    if missing:
        raise HTTPException(
            status_code=500,
            detail=f"Media storage is not configured: {', '.join(missing)}",
        )


def _client():
    _require_r2_settings()
    return boto3.client(
        "s3",
        endpoint_url=settings.R2_ENDPOINT,
        aws_access_key_id=settings.R2_ACCESS_KEY,
        aws_secret_access_key=settings.R2_SECRET_KEY,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )


def upload_bytes(key: str, data: bytes, content_type: str) -> str:
    """Upload raw bytes to R2 and return the public URL."""
    _client().put_object(
        Bucket=settings.R2_BUCKET,
        Key=key,
        Body=data,
        ContentType=content_type,
    )
    return f"{settings.R2_PUBLIC_BASE.rstrip('/')}/{key}"


def delete_object(url: str) -> None:
    """Delete an object from R2 by its public URL (best-effort)."""
    public_base = settings.R2_PUBLIC_BASE.rstrip("/")
    if not url or not public_base or not url.startswith(public_base):
        return
    key = url[len(public_base) + 1:]
    try:
        _client().delete_object(Bucket=settings.R2_BUCKET, Key=key)
    except Exception:
        pass


def ext_for(content_type: str) -> str:
    ext = mimetypes.guess_extension(content_type)
    return {".jpe": ".jpg", ".jpeg": ".jpg", None: ".jpg"}.get(ext, ext or ".jpg")
