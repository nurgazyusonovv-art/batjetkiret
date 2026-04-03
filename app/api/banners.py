"""Public + admin banner endpoints."""
import base64
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import get_db, require_admin
from app.models.banner import Banner

router = APIRouter()

_ALLOWED_IMG = {"image/jpeg", "image/png", "image/webp", "image/gif"}
_EXT_MIME = {".jpg": "image/jpeg", ".jpeg": "image/jpeg",
             ".png": "image/png", ".webp": "image/webp", ".gif": "image/gif"}


def _banner_out(b: Banner) -> dict:
    return {
        "id": b.id,
        "title": b.title,
        "subtitle": b.subtitle,
        "image_data": b.image_data,
        "link_url": b.link_url,
        "is_active": b.is_active,
        "sort_order": b.sort_order,
    }


# ── Public ────────────────────────────────────────────────────────────────────

@router.get("/banners")
def get_active_banners(db: Session = Depends(get_db)):
    """Return active banners sorted by sort_order. No auth required."""
    banners = (
        db.query(Banner)
        .filter(Banner.is_active == True)
        .order_by(Banner.sort_order.asc(), Banner.id.asc())
        .all()
    )
    return [_banner_out(b) for b in banners]


# ── Admin ─────────────────────────────────────────────────────────────────────

class BannerCreate(BaseModel):
    title: Optional[str] = None
    subtitle: Optional[str] = None
    link_url: Optional[str] = None
    is_active: bool = True
    sort_order: int = 0


class BannerUpdate(BaseModel):
    title: Optional[str] = None
    subtitle: Optional[str] = None
    link_url: Optional[str] = None
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None


@router.get("/admin/banners")
def admin_get_banners(db: Session = Depends(get_db), admin=Depends(require_admin)):
    banners = db.query(Banner).order_by(Banner.sort_order.asc(), Banner.id.asc()).all()
    return [_banner_out(b) for b in banners]


@router.post("/admin/banners")
def admin_create_banner(data: BannerCreate, db: Session = Depends(get_db), admin=Depends(require_admin)):
    b = Banner(
        title=data.title,
        subtitle=data.subtitle,
        link_url=data.link_url,
        is_active=data.is_active,
        sort_order=data.sort_order,
    )
    db.add(b)
    db.commit()
    db.refresh(b)
    return _banner_out(b)


@router.put("/admin/banners/{banner_id}")
def admin_update_banner(banner_id: int, data: BannerUpdate, db: Session = Depends(get_db), admin=Depends(require_admin)):
    b = db.query(Banner).filter(Banner.id == banner_id).first()
    if not b:
        raise HTTPException(status_code=404, detail="Баннер табылган жок")
    if data.title is not None:
        b.title = data.title
    if data.subtitle is not None:
        b.subtitle = data.subtitle
    if data.link_url is not None:
        b.link_url = data.link_url
    if data.is_active is not None:
        b.is_active = data.is_active
    if data.sort_order is not None:
        b.sort_order = data.sort_order
    db.commit()
    db.refresh(b)
    return _banner_out(b)


@router.delete("/admin/banners/{banner_id}")
def admin_delete_banner(banner_id: int, db: Session = Depends(get_db), admin=Depends(require_admin)):
    b = db.query(Banner).filter(Banner.id == banner_id).first()
    if not b:
        raise HTTPException(status_code=404, detail="Баннер табылган жок")
    db.delete(b)
    db.commit()
    return {"ok": True}


@router.post("/admin/banners/{banner_id}/image")
async def admin_upload_banner_image(
    banner_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    b = db.query(Banner).filter(Banner.id == banner_id).first()
    if not b:
        raise HTTPException(status_code=404, detail="Баннер табылган жок")

    import os
    ext = os.path.splitext(file.filename or "")[1].lower()
    mime = _EXT_MIME.get(ext, file.content_type or "image/jpeg")
    if mime not in _ALLOWED_IMG:
        raise HTTPException(status_code=400, detail="Сүрөт форматы колдонулбайт")

    raw = await file.read()
    if len(raw) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Сүрөт өлчөмү 5MB дан ашпасын")

    b.image_data = f"data:{mime};base64,{base64.b64encode(raw).decode()}"
    db.commit()
    return {"image_data": b.image_data}
