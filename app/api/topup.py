from datetime import datetime, timedelta
import hashlib
import logging
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.models.topup import TopUpRequest
from app.models.user import User
from app.models.notification import Notification
from app.services import fcm as fcm_service
from app.services.media_upload import upload_image_file

logger = logging.getLogger(__name__)


class TopupRequestBody(BaseModel):
    amount: float
    screenshot_url: str

router = APIRouter(prefix="/topup", tags=["TopUp"])

@router.post("/upload-screenshot")
async def upload_screenshot(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    uploaded = await upload_image_file(
        file=file,
        key_prefix=f"topups/{current_user.id}/{int(datetime.utcnow().timestamp())}",
        max_bytes=10 * 1024 * 1024,
    )
    return {"url": uploaded.url}


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

    admins = db.query(User).filter(User.is_admin == True).all()  # noqa: E712
    for admin in admins:
        db.add(
            Notification(
                user_id=admin.id,
                title="💳 Жаңы топап өтүнүчү",
                message=f"{current_user.name} ({current_user.phone}) — {amount} сом",
            )
        )

    db.commit()
    db.refresh(req)

    # FCM push — admins who have token
    for admin in admins:
        if admin.fcm_token:
            ok = fcm_service.send_push(
                token=admin.fcm_token,
                title="💳 Жаңы топап өтүнүчү",
                body=f"{current_user.name} ({current_user.phone}) — {int(amount)} сом",
                channel_id="topup_requests",
            )
            logger.info("FCM topup to admin_id=%s: %s", admin.id, "ok" if ok else "failed")

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
