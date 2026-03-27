from datetime import datetime, timedelta
import base64
import hashlib
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.models.topup import TopUpRequest
from app.models.user import User
from app.models.notification import Notification


class TopupRequestBody(BaseModel):
    amount: float
    screenshot_url: str

router = APIRouter(prefix="/topup", tags=["TopUp"])

_MIME_BY_EXT = {
    ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
    ".png": "image/png", ".webp": "image/webp",
    ".gif": "image/gif", ".heic": "image/heic", ".heif": "image/heif",
}
_ALLOWED_TYPES = set(_MIME_BY_EXT.values())


@router.post("/upload-screenshot")
async def upload_screenshot(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    import os
    ext = os.path.splitext(file.filename or "")[1].lower() or ".jpg"
    mime = (file.content_type or "").lower()
    if mime not in _ALLOWED_TYPES and ext not in _MIME_BY_EXT:
        raise HTTPException(status_code=400, detail="Only image files are allowed")

    content = await file.read()
    if len(content) > 10 * 1024 * 1024:  # 10 MB limit
        raise HTTPException(status_code=400, detail="File too large (max 10MB)")

    # Resolve mime type from extension if content_type is missing
    if mime not in _ALLOWED_TYPES:
        mime = _MIME_BY_EXT.get(ext, "image/jpeg")

    encoded = base64.b64encode(content).decode("ascii")
    data_url = f"data:{mime};base64,{encoded}"
    return {"url": data_url}


@router.post("/request")
def create_topup_request(
    body: TopupRequestBody,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    amount = body.amount
    screenshot_url = body.screenshot_url

    if amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")

    screenshot_hash = hashlib.sha256(
        screenshot_url.encode()
    ).hexdigest()

    existing = (
        db.query(TopUpRequest)
        .filter(TopUpRequest.screenshot_hash == screenshot_hash)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=400,
            detail="This payment proof was already submitted",
        )

    req = TopUpRequest(
        user_id=current_user.id,
        amount=amount,
        screenshot_url=screenshot_url,
        screenshot_hash=screenshot_hash,
        expires_at=datetime.utcnow() + timedelta(hours=48),
    )
    db.add(req)

    admins = db.query(User).filter(User.is_admin == True).all()
    for admin in admins:
        db.add(
            Notification(
                user_id=admin.id,
                title="New Top-up Request",
                message=f"User {current_user.phone} requested top-up: {amount} KGS",
            )
        )

    db.commit()
    db.refresh(req)

    return {
        "message": "Top-up request submitted",
        "status": "PENDING",
        "expires_at": req.expires_at,
    }

@router.get("/my")
def my_topups(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    reqs = (
        db.query(TopUpRequest)
        .filter(TopUpRequest.user_id == current_user.id)
        .order_by(TopUpRequest.created_at.desc())
        .all()
    )

    return [
        {
            "id": r.id,
            "amount": float(r.amount),
            "approved_amount": float(r.approved_amount) if r.approved_amount else None,
            "status": r.status.lower(),
            "screenshot_url": r.screenshot_url,
            "created_at": r.created_at,
            "admin_note": r.admin_note,
        }
        for r in reqs
    ]
