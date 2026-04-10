from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.models.user import User


class UpdateFcmTokenRequest(BaseModel):
    token: str

router = APIRouter(prefix="/users", tags=["Users"])

class UpdateUserRequest(BaseModel):
    name: str | None = None
    phone: str | None = None
    address: str | None = None
    is_online: bool | None = None


class UpdateLocationRequest(BaseModel):
    latitude: float
    longitude: float

@router.get("/me")
def get_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return {
        "id": current_user.id,
        "phone": current_user.phone,
        "name": current_user.name,
        "is_courier": current_user.is_courier,
        "is_admin": current_user.is_admin,
        "balance": float(current_user.balance or 0),
        "address": current_user.address,
        "is_online": current_user.is_online,
        "unique_id": current_user.unique_id,
        "created_at": current_user.created_at,
    }

@router.put("/me")
def update_me(
    request: UpdateUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Fetch fresh user object from DB
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Update fields if provided
    if request.name:
        user.name = request.name
    if request.phone:
        # Check if phone is already taken by another user
        existing_user = db.query(User).filter(
            User.phone == request.phone,
            User.id != user.id
        ).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Phone already in use")
        user.phone = request.phone
    if request.address is not None:
        user.address = request.address
    if request.is_online is not None:
        user.is_online = request.is_online

    db.commit()
    db.refresh(user)

    return {
        "id": user.id,
        "phone": user.phone,
        "name": user.name,
        "is_courier": user.is_courier,
        "is_admin": user.is_admin,
        "balance": float(user.balance or 0),
        "address": user.address,
        "is_online": user.is_online,
        "created_at": user.created_at,
    }


@router.put("/me/location")
def update_location(
    request: UpdateLocationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.current_latitude = request.latitude
    user.current_longitude = request.longitude
    db.commit()
    return {"ok": True}


@router.post("/me/fcm-token")
def update_fcm_token(
    request: UpdateFcmTokenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.fcm_token = request.token
    db.commit()
    return {"ok": True}


# ── Web Push subscriptions (Flutter web) ──────────────────────────────────────

class UserPushSubscribeRequest(BaseModel):
    subscription: dict


@router.get("/vapid-key")
def get_vapid_key_user():
    """Return the VAPID public key (public endpoint for Flutter web)."""
    from app.core.config import settings
    return {"public_key": settings.VAPID_PUBLIC_KEY}


@router.post("/me/push-subscribe")
def user_push_subscribe(
    body: UserPushSubscribeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Save a Web Push subscription for the current user (Flutter web)."""
    import json
    from app.models.user_push_subscription import UserPushSubscription

    sub_json = json.dumps(body.subscription)
    endpoint = body.subscription.get("endpoint", "")

    existing = db.query(UserPushSubscription).filter(
        UserPushSubscription.user_id == current_user.id,
        UserPushSubscription.subscription_json.contains(endpoint[:80]),
    ).first()
    if existing:
        existing.subscription_json = sub_json
    else:
        db.add(UserPushSubscription(user_id=current_user.id, subscription_json=sub_json))
    db.commit()
    return {"ok": True}


@router.delete("/me/push-subscribe")
def user_push_unsubscribe(
    body: UserPushSubscribeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    import json
    from app.models.user_push_subscription import UserPushSubscription

    endpoint = body.subscription.get("endpoint", "")
    db.query(UserPushSubscription).filter(
        UserPushSubscription.user_id == current_user.id,
        UserPushSubscription.subscription_json.contains(endpoint[:80]),
    ).delete(synchronize_session=False)
    db.commit()
    return {"ok": True}
