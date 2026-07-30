"""Shared image upload validation and R2 storage."""
import os
from dataclasses import dataclass

from fastapi import HTTPException, UploadFile

from app.services.r2 import delete_object, ext_for, upload_bytes


IMAGE_MIME_BY_EXT = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".gif": "image/gif",
    ".heic": "image/heic",
    ".heif": "image/heif",
}


@dataclass(frozen=True)
class StoredUpload:
    url: str
    content_type: str
    size: int


def _resolve_image_mime(file: UploadFile) -> str:
    ext = os.path.splitext(file.filename or "")[1].lower()
    content_type = (file.content_type or "").lower()

    if content_type == "application/octet-stream":
        content_type = ""

    if content_type in IMAGE_MIME_BY_EXT.values():
        return content_type

    if ext in IMAGE_MIME_BY_EXT:
        return IMAGE_MIME_BY_EXT[ext]

    raise HTTPException(status_code=400, detail="Сүрөт форматы туура эмес")


async def upload_image_file(
    file: UploadFile,
    key_prefix: str,
    max_bytes: int,
    old_url: str | None = None,
) -> StoredUpload:
    content_type = _resolve_image_mime(file)
    content = await file.read()

    if not content:
        raise HTTPException(status_code=400, detail="Сүрөт файлы бош")

    if len(content) > max_bytes:
        max_mb = max_bytes // (1024 * 1024)
        raise HTTPException(status_code=400, detail=f"Файл өтө чоң (макс {max_mb}МБ)")

    if old_url:
        delete_object(old_url)

    key = f"{key_prefix}{ext_for(content_type)}"
    url = upload_bytes(key, content, content_type)
    return StoredUpload(url=url, content_type=content_type, size=len(content))
