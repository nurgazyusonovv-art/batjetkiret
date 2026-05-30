"""Cloudflare R2 object storage helpers."""
import mimetypes
import boto3
from botocore.config import Config

R2_ACCESS_KEY = "dd3e6acf2fe48209abcc98e27c0afbcb"
R2_SECRET_KEY = "5c0efbe07b59feae5a5ebdb007034ea6ae340a988adfebb731d591a9ae09d5f5"
R2_ENDPOINT   = "https://90f676223297515e8526b77b1dc26aff.r2.cloudflarestorage.com"
R2_BUCKET     = "batjetkiret-media"
PUBLIC_BASE   = "https://pub-a3151ae89aa0437f833a8e4e4c80288e.r2.dev"


def _client():
    return boto3.client(
        "s3",
        endpoint_url=R2_ENDPOINT,
        aws_access_key_id=R2_ACCESS_KEY,
        aws_secret_access_key=R2_SECRET_KEY,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )


def upload_bytes(key: str, data: bytes, content_type: str) -> str:
    """Upload raw bytes to R2 and return the public URL."""
    _client().put_object(
        Bucket=R2_BUCKET,
        Key=key,
        Body=data,
        ContentType=content_type,
    )
    return f"{PUBLIC_BASE}/{key}"


def delete_object(url: str) -> None:
    """Delete an object from R2 by its public URL (best-effort)."""
    if not url or not url.startswith(PUBLIC_BASE):
        return
    key = url[len(PUBLIC_BASE) + 1:]
    try:
        _client().delete_object(Bucket=R2_BUCKET, Key=key)
    except Exception:
        pass


def ext_for(content_type: str) -> str:
    ext = mimetypes.guess_extension(content_type)
    return {".jpe": ".jpg", ".jpeg": ".jpg", None: ".jpg"}.get(ext, ext or ".jpg")
