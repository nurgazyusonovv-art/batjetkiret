from urllib.parse import urlparse
import urllib.request

from fastapi import APIRouter, HTTPException, Response

router = APIRouter(prefix="/media", tags=["Media"])

_MAX_PROXY_BYTES = 8 * 1024 * 1024
_ALLOWED_HOST_SUFFIXES = (".r2.dev",)
_ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
}


@router.get("/proxy")
def proxy_media(url: str):
    parsed = urlparse(url)
    host = (parsed.hostname or "").lower()
    if parsed.scheme != "https" or not any(
        host.endswith(suffix) for suffix in _ALLOWED_HOST_SUFFIXES
    ):
        raise HTTPException(status_code=400, detail="Unsupported media URL")

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "BatkenExpress/1.0"})
        with urllib.request.urlopen(req, timeout=12) as resp:
            content_type = (resp.headers.get("Content-Type") or "").split(";")[0].strip()
            if content_type not in _ALLOWED_CONTENT_TYPES:
                raise HTTPException(status_code=415, detail="Unsupported media type")

            data = resp.read(_MAX_PROXY_BYTES + 1)
            if len(data) > _MAX_PROXY_BYTES:
                raise HTTPException(status_code=413, detail="Media file is too large")
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=502, detail="Media fetch failed") from exc

    return Response(
        content=data,
        media_type=content_type,
        headers={
            "Cache-Control": "public, max-age=86400",
            "Access-Control-Allow-Origin": "*",
        },
    )
