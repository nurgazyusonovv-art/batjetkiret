"""Public + admin ad-popup (broadcast advertisement) endpoints."""
import base64
import os
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import get_db, require_admin
from app.models.ad_popup import AdPopup
from app.models.enterprise import Enterprise

router = APIRouter()

_ALLOWED_IMG = {"image/jpeg", "image/png", "image/webp", "image/gif"}
_EXT_MIME = {".jpg": "image/jpeg", ".jpeg": "image/jpeg",
             ".png": "image/png", ".webp": "image/webp", ".gif": "image/gif"}


def _out(p: AdPopup, db: Session) -> dict:
    enterprise_name = None
    enterprise_category = None
    if p.enterprise_id:
        ent = db.query(Enterprise).filter(Enterprise.id == p.enterprise_id).first()
        if ent:
            enterprise_name = ent.name
            enterprise_category = ent.category
    return {
        "id": p.id,
        "title": p.title,
        "subtitle": p.subtitle,
        "image_data": p.image_data,
        "link_url": p.link_url,
        "enterprise_id": p.enterprise_id,
        "enterprise_name": enterprise_name,
        "enterprise_category": enterprise_category,
        "is_active": p.is_active,
        "created_at": p.created_at.isoformat() if p.created_at else None,
    }


# ── Public ─────────────────────────────────────────────────────────────────────

@router.get("/ad-popup")
def get_current_popup(db: Session = Depends(get_db)):
    """Return the latest active ad popup. Returns null if none active."""
    popup = (
        db.query(AdPopup)
        .filter(AdPopup.is_active == True)
        .order_by(AdPopup.id.desc())
        .first()
    )
    if not popup:
        return None
    return _out(popup, db)


# ── Admin ──────────────────────────────────────────────────────────────────────

class PopupCreate(BaseModel):
    title: Optional[str] = None
    subtitle: Optional[str] = None
    link_url: Optional[str] = None
    enterprise_id: Optional[int] = None


@router.get("/admin/ad-popup")
def admin_get_popups(db: Session = Depends(get_db), admin=Depends(require_admin)):
    """Return all popups (latest first)."""
    popups = db.query(AdPopup).order_by(AdPopup.id.desc()).all()
    return [_out(p, db) for p in popups]


@router.post("/admin/ad-popup")
def admin_send_popup(
    data: PopupCreate,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    """Create new popup and deactivate all previous ones."""
    # Deactivate all existing active popups
    db.query(AdPopup).filter(AdPopup.is_active == True).update({"is_active": False})
    db.commit()

    p = AdPopup(
        title=data.title,
        subtitle=data.subtitle,
        link_url=data.link_url,
        enterprise_id=data.enterprise_id,
        is_active=True,
    )
    db.add(p)
    db.commit()
    db.refresh(p)
    return _out(p, db)


@router.post("/admin/ad-popup/{popup_id}/image")
async def admin_upload_popup_image(
    popup_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    p = db.query(AdPopup).filter(AdPopup.id == popup_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Popup табылган жок")

    ext = os.path.splitext(file.filename or "")[1].lower()
    mime = _EXT_MIME.get(ext, file.content_type or "image/jpeg")
    if mime not in _ALLOWED_IMG:
        raise HTTPException(status_code=400, detail="Сүрөт форматы колдонулбайт")

    raw = await file.read()
    if len(raw) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Сүрөт өлчөмү 5MB дан ашпасын")

    p.image_data = f"data:{mime};base64,{base64.b64encode(raw).decode()}"
    db.commit()
    return _out(p, db)


@router.delete("/admin/ad-popup/{popup_id}")
def admin_delete_popup(
    popup_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    p = db.query(AdPopup).filter(AdPopup.id == popup_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Popup табылган жок")
    db.delete(p)
    db.commit()
    return {"ok": True}


@router.patch("/admin/ad-popup/{popup_id}/deactivate")
def admin_deactivate_popup(
    popup_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    p = db.query(AdPopup).filter(AdPopup.id == popup_id).first()
    if not p:
        raise HTTPException(status_code=404, detail="Popup табылган жок")
    p.is_active = False
    db.commit()
    return _out(p, db)
