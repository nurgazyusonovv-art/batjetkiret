from datetime import datetime, timedelta
import hashlib
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.models.topup import TopUpRequest
from app.models.user import User
from app.models.notification import Notification

router = APIRouter(prefix="/topup", tags=["TopUp"])

@router.post("/request")
def create_topup_request(
    amount: float,
    screenshot_url: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
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
        requested_amount=amount,
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
            "amount": float(r.requested_amount),
            "status": r.status,
            "created_at": r.created_at,
            "note": r.admin_note,
        }
        for r in reqs
    ]
