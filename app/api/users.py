from fastapi import APIRouter, Depends, HTTPException, status
from typing import Literal

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.api.deps import get_db, get_current_user
from app.models.user import User
from app.models.order import Order
from app.models.chat_room import ChatRoom
from app.models.message import Message
from app.models.order_status_log import OrderStatusLog
from app.models.courier_rating import CourierRating
from app.models.user_rating import UserRating
from app.models.transaction import Transaction
from app.models.notification import Notification
from app.models.password_reset import PasswordReset
from app.models.topup_request import TopUpRequest


class UpdateFcmTokenRequest(BaseModel):
    token: str

router = APIRouter(prefix="/users", tags=["Users"])

class UpdateUserRequest(BaseModel):
    name: str | None = None
    phone: str | None = None
    address: str | None = None
    is_online: bool | None = None
    courier_transport: Literal["walking", "car", "cargo", "scooter"] | None = None
    courier_vehicle_plate: str | None = Field(default=None, max_length=32)
    courier_vehicle_brand: str | None = Field(default=None, max_length=64)
    courier_vehicle_color: str | None = Field(default=None, max_length=64)


class UpdateLocationRequest(BaseModel):
    latitude: float
    longitude: float


def _user_payload(user: User) -> dict:
    return {
        "id": user.id,
        "phone": user.phone,
        "name": user.name,
        "is_courier": user.is_courier,
        "is_admin": user.is_admin,
        "balance": float(user.balance or 0),
        "address": user.address,
        "is_online": user.is_online,
        "unique_id": user.unique_id,
        "courier_transport": user.courier_transport or "walking",
        "courier_vehicle_plate": user.courier_vehicle_plate,
        "courier_vehicle_brand": user.courier_vehicle_brand,
        "courier_vehicle_color": user.courier_vehicle_color,
        "created_at": user.created_at,
    }

@router.get("/me")
def get_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _user_payload(current_user)

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
    if (
        request.courier_transport is not None
        or request.courier_vehicle_plate is not None
        or request.courier_vehicle_brand is not None
        or request.courier_vehicle_color is not None
    ):
        if not user.is_courier:
            raise HTTPException(
                status_code=403,
                detail="Транспорт маалыматын курьер гана өзгөртө алат",
            )
        transport = request.courier_transport or user.courier_transport or "walking"
        plate = (
            request.courier_vehicle_plate
            if request.courier_vehicle_plate is not None
            else user.courier_vehicle_plate
        )
        plate = " ".join((plate or "").strip().upper().split())
        brand = (
            request.courier_vehicle_brand
            if request.courier_vehicle_brand is not None
            else user.courier_vehicle_brand
        )
        color = (
            request.courier_vehicle_color
            if request.courier_vehicle_color is not None
            else user.courier_vehicle_color
        )
        brand = " ".join((brand or "").strip().split())
        color = " ".join((color or "").strip().split())
        if transport in {"car", "cargo"}:
            missing_fields = []
            if not plate:
                missing_fields.append("мамлекеттик номерин")
            if not brand:
                missing_fields.append("маркасын")
            if not color:
                missing_fields.append("түсүн")
            if missing_fields:
                raise HTTPException(
                    status_code=400,
                    detail=f"Автоунаанын {', '.join(missing_fields)} жазыңыз",
                )
        user.courier_transport = transport
        user.courier_vehicle_plate = plate if transport in {"car", "cargo"} else None
        user.courier_vehicle_brand = brand if transport in {"car", "cargo"} else None
        user.courier_vehicle_color = color if transport in {"car", "cargo"} else None

    db.commit()
    db.refresh(user)

    return _user_payload(user)


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


@router.delete("/me")
def delete_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete current user's account and associated personal data."""
    user_id = current_user.id
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Колдонуучу табылган жок")

    # Clean owned orders and related records
    owned_order_ids = [row[0] for row in db.query(Order.id).filter(Order.user_id == user_id).all()]
    if owned_order_ids:
        order_chat_ids = [
            row[0]
            for row in db.query(ChatRoom.id).filter(ChatRoom.order_id.in_(owned_order_ids)).all()
        ]
        if order_chat_ids:
            db.query(Message).filter(Message.chat_id.in_(order_chat_ids)).delete(synchronize_session=False)
        db.query(ChatRoom).filter(ChatRoom.order_id.in_(owned_order_ids)).delete(synchronize_session=False)
        db.query(OrderStatusLog).filter(OrderStatusLog.order_id.in_(owned_order_ids)).delete(synchronize_session=False)
        db.query(CourierRating).filter(CourierRating.order_id.in_(owned_order_ids)).delete(synchronize_session=False)
        db.query(UserRating).filter(UserRating.order_id.in_(owned_order_ids)).delete(synchronize_session=False)
        db.query(Transaction).filter(Transaction.order_id.in_(owned_order_ids)).delete(synchronize_session=False)
        db.query(Order).filter(Order.id.in_(owned_order_ids)).delete(synchronize_session=False)

    # Clean references where this user appears
    db.query(OrderStatusLog).filter(OrderStatusLog.actor_user_id == user_id).delete(synchronize_session=False)
    db.query(Transaction).filter(Transaction.user_id == user_id).delete(synchronize_session=False)
    db.query(Notification).filter(Notification.user_id == user_id).delete(synchronize_session=False)
    db.query(PasswordReset).filter(PasswordReset.user_id == user_id).delete(synchronize_session=False)
    db.query(CourierRating).filter(
        or_(CourierRating.user_id == user_id, CourierRating.courier_id == user_id)
    ).delete(synchronize_session=False)
    db.query(UserRating).filter(
        or_(UserRating.rater_id == user_id, UserRating.target_user_id == user_id)
    ).delete(synchronize_session=False)

    db.query(Message).filter(Message.sender_id == user_id).delete(synchronize_session=False)

    db.query(ChatRoom).filter(ChatRoom.user_id == user_id).update({ChatRoom.user_id: None}, synchronize_session=False)
    db.query(ChatRoom).filter(ChatRoom.courier_id == user_id).update({ChatRoom.courier_id: None}, synchronize_session=False)
    db.query(ChatRoom).filter(ChatRoom.admin_id == user_id).update({ChatRoom.admin_id: None}, synchronize_session=False)

    db.query(Order).filter(Order.courier_id == user_id).update({Order.courier_id: None}, synchronize_session=False)
    db.query(TopUpRequest).filter(TopUpRequest.user_id == user_id).update({TopUpRequest.user_id: None}, synchronize_session=False)

    db.delete(user)
    db.commit()
    return {"ok": True, "message": "Account successfully deleted"}

