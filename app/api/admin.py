from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from typing import Literal
import random
import logging
import os

from app.api.deps import get_db, require_admin
from app.models.order import Order
from app.models.rating import CourierRating
from app.models.user import User
from app.models.transaction import Transaction
from app.models.topup import TopUpRequest
from app.models.user_rating import UserRating
from app.services.wallet import refund, payout
from app.models.notification import Notification
from app.models.order_status_log import OrderStatusLog
from datetime import datetime, timedelta
from app.services.wallet import topup
from app.models.chat import ChatRoom
from app.models.message import Message
from app.models.password_reset import PasswordReset
from app.services.order_status import apply_status_change

router = APIRouter(prefix="/admin", tags=["Admin"])
logger = logging.getLogger(__name__)

USER_ORDER_SERVICE_FEE = 5.0
COURIER_ORDER_SERVICE_FEE = 5.0
TOTAL_SERVICE_FEE_PER_COMPLETED_ORDER = USER_ORDER_SERVICE_FEE + COURIER_ORDER_SERVICE_FEE



class AdminUserUpdateRequest(BaseModel):
    name: str | None = None
    phone: str | None = None
    role: Literal["user", "courier", "admin"] | None = None
    is_active: bool | None = None


class NotificationCreate(BaseModel):
    title: str
    message: str

def _generate_unique_user_id(db: Session) -> str:
    """Generate a unique reference id in BJ000123 format."""
    while True:
        number = random.randint(1, 999999)
        unique_id = f"BJ{number:06d}"
        exists = db.query(User.id).filter(User.unique_id == unique_id).first()
        if not exists:
            return unique_id


def _ensure_user_unique_id(user: User, db: Session) -> str:
    """Return existing unique_id or create a new one for legacy users."""
    if user.unique_id:
        return user.unique_id
    user.unique_id = _generate_unique_user_id(db)
    return user.unique_id


@router.get("/ratings")
def all_ratings(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    ratings = db.query(CourierRating).order_by(CourierRating.created_at.desc()).offset(skip).limit(limit).all()

    return [
        {
            "order_id": r.order_id,
            "courier_id": r.courier_id,
            "user_id": r.user_id,
            "rating": r.rating,
            "comment": r.comment,
            "created_at": r.created_at,
        }
        for r in ratings
    ]

@router.get("/user-ratings")
def all_user_ratings(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    ratings = db.query(UserRating).order_by(UserRating.created_at.desc()).offset(skip).limit(limit).all()

    return [
        {
            "order_id": r.order_id,
            "rater_id": r.rater_id,
            "target_user_id": r.target_user_id,
            "rating": r.rating,
            "comment": r.comment,
            "created_at": r.created_at,
        }
        for r in ratings
    ]


@router.get("/support-chats")
def support_chats(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    chats = (
        db.query(ChatRoom)
        .filter(ChatRoom.type == "SUPPORT")
        .order_by(ChatRoom.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    return [
        {
            "chat_id": c.id,
            "user_id": c.user_id,
            "courier_id": c.courier_id,
            "created_at": c.created_at,
        }
        for c in chats
    ]


@router.post("/topups/{topup_id}/approve")
def approve_topup(
    topup_id: int,
    approved_amount: float,
    note: str | None = None,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    req = db.query(TopUpRequest).filter(TopUpRequest.id == topup_id).first()

    if not req or req.status != "PENDING":
        raise HTTPException(status_code=404)

    if req.expires_at < datetime.utcnow():
        req.status = "EXPIRED"
        db.commit()
        raise HTTPException(status_code=400, detail="Request expired")

    user = db.query(User).filter(User.id == req.user_id).first()

    topup(db, user, approved_amount)

    req.approved_amount = approved_amount
    req.status = "APPROVED"
    req.admin_note = note
    req.approved_by_admin_id = admin.id
    req.approved_at = datetime.utcnow()

    db.commit()

    return {"message": "Top-up approved"}


@router.post("/topups/{topup_id}/reject")
def reject_topup(
    topup_id: int,
    note: str,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    req = db.query(TopUpRequest).filter(TopUpRequest.id == topup_id).first()
    if not req or req.status != "PENDING":
        raise HTTPException(status_code=404)

    req.status = "REJECTED"
    req.admin_note = note
    req.approved_by_admin_id = admin.id
    req.approved_at = datetime.utcnow()

    db.commit()

    return {"message": "Top-up rejected"}




@router.get("/notifications")
def admin_notifications(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    notifs = (
        db.query(Notification)
        .order_by(Notification.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    return [
        {
            "id": n.id,
            "title": n.title,
            "message": n.message,
            "is_read": n.is_read,
            "created_at": n.created_at,
        }
        for n in notifs
    ]

@router.post("/notifications/{notif_id}/read")
def mark_notification_read(
    notif_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    notif = db.query(Notification).filter(Notification.id == notif_id).first()
    if not notif:
        raise HTTPException(status_code=404)

    notif.is_read = True
    db.commit()

    return {"message": "Notification marked as read"}


@router.post("/notifications")
def create_notification(
    payload: NotificationCreate,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    """Create a new notification (can be called from app or internally)"""
    notif = Notification(
        title=payload.title,
        message=payload.message,
        is_read=False,
        user_id=1,
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)

    return {
        "id": notif.id,
        "title": notif.title,
        "message": notif.message,
        "is_read": notif.is_read,
        "created_at": notif.created_at,
    }


@router.post("/notifications/broadcast")
def broadcast_notification(
    payload: NotificationCreate,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    """Send a notification to ALL active users at once."""
    users = db.query(User).filter(User.is_active == True).all()  # noqa: E712

    notifs = [
        Notification(
            user_id=u.id,
            title=payload.title,
            message=payload.message,
            is_read=False,
        )
        for u in users
    ]
    db.bulk_save_objects(notifs)
    db.commit()

    return {"sent_to": len(notifs), "message": f"{len(notifs)} колдонуучуга жөнөтүлдү"}



@router.get("/notifications/unread-count")
def unread_notifications_count(
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    count = (
        db.query(func.count(Notification.id))
        .filter(Notification.is_read == False)
        .scalar()
    )

    return {"unread": count}

@router.delete("/notifications/{notif_id}")
def delete_notification(
    notif_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    notif = db.query(Notification).filter(Notification.id == notif_id).first()
    if not notif:
        raise HTTPException(status_code=404)

    db.delete(notif)
    db.commit()

    return {"message": "Notification deleted"}



@router.get("/orders")
def all_orders(
    skip: int = 0,
    limit: int = 100,
    today_only: bool = False,
    order_date: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    query = db.query(Order).filter(Order.source != "dine_in")

    # Priority: explicit date filter, then date range, fallback to today_only toggle.
    if order_date:
        try:
            selected_date = datetime.strptime(order_date, "%Y-%m-%d")
        except ValueError as exc:
            raise HTTPException(status_code=400, detail="order_date must be YYYY-MM-DD") from exc

        start = selected_date.replace(hour=0, minute=0, second=0, microsecond=0)
        end = start.replace(hour=23, minute=59, second=59, microsecond=999999)
        query = query.filter(Order.created_at >= start, Order.created_at <= end)
    elif date_from or date_to:
        if date_from:
            try:
                from_dt = datetime.strptime(date_from, "%Y-%m-%d").replace(
                    hour=0, minute=0, second=0, microsecond=0
                )
            except ValueError as exc:
                raise HTTPException(status_code=400, detail="date_from must be YYYY-MM-DD") from exc
            query = query.filter(Order.created_at >= from_dt)

        if date_to:
            try:
                to_dt = datetime.strptime(date_to, "%Y-%m-%d").replace(
                    hour=23, minute=59, second=59, microsecond=999999
                )
            except ValueError as exc:
                raise HTTPException(status_code=400, detail="date_to must be YYYY-MM-DD") from exc
            query = query.filter(Order.created_at <= to_dt)
    elif today_only:
        today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
        query = query.filter(Order.created_at >= today_start)

    orders = query.order_by(Order.created_at.desc()).offset(skip).limit(limit).all()

    return [
        {
            "id": o.id,
            "user_id": o.user_id,
            "user_phone": o.user.phone if o.user else None,
            "courier_id": o.courier_id,
            "courier_phone": o.courier.phone if o.courier else None,
            "category": o.category,
            "description": o.description,
            "from_address": o.from_address,
            "to_address": o.to_address,
            "distance_km": float(o.distance_km),
            "price": float(o.price),
            "status": o.status,
            "admin_note": o.admin_note,
            "created_at": o.created_at,
        }
        for o in orders
    ]

@router.get("/stats")
def system_stats(
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    from datetime import datetime
    
    # All-time stats
    total_orders = db.query(func.count(Order.id)).filter(Order.enterprise_id == None).scalar()
    waiting_orders = (
        db.query(func.count(Order.id))
        .filter(Order.status == "WAITING_COURIER", Order.enterprise_id == None)
        .scalar()
    )
    completed_orders = (
        db.query(func.count(Order.id))
        .filter(Order.status == "COMPLETED", Order.enterprise_id == None)
        .scalar()
    )

    # Business rule: each completed order brings fixed 10 som platform revenue (5 user + 5 courier).
    total_revenue = float(completed_orders or 0) * TOTAL_SERVICE_FEE_PER_COMPLETED_ORDER

    # Today's stats
    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    
    total_orders_today = (
        db.query(func.count(Order.id))
        .filter(Order.created_at >= today_start, Order.enterprise_id == None)
        .scalar()
    )
    
    canceled_orders_today = (
        db.query(func.count(Order.id))
        .filter(
            Order.created_at >= today_start,
            Order.status.in_(["CANCELED", "CANCELLED"]),
            Order.enterprise_id == None
        )
        .scalar()
    )
    
    delivered_orders_today = (
        db.query(func.count(Order.id))
        .filter(
            Order.created_at >= today_start,
            Order.status == "COMPLETED",
            Order.enterprise_id == None
        )
        .scalar()
    )
    
    revenue_today = float(delivered_orders_today or 0) * TOTAL_SERVICE_FEE_PER_COMPLETED_ORDER

    total_users = db.query(func.count(User.id)).scalar()
    total_couriers = (
        db.query(func.count(User.id))
        .filter(User.is_courier == True)
        .scalar()
    )
    online_couriers = (
        db.query(func.count(User.id))
        .filter(User.is_courier == True, User.is_online == True, User.is_active == True)
        .scalar()
    )

    approved_topups_count = (
        db.query(func.count(TopUpRequest.id))
        .filter(TopUpRequest.status == "APPROVED")
        .scalar()
    )
    rejected_topups_count = (
        db.query(func.count(TopUpRequest.id))
        .filter(TopUpRequest.status == "REJECTED")
        .scalar()
    )
    pending_topups_count = (
        db.query(func.count(TopUpRequest.id))
        .filter(TopUpRequest.status == "PENDING")
        .scalar()
    )

    approved_topups_amount = (
        db.query(func.coalesce(func.sum(TopUpRequest.amount), 0))
        .filter(TopUpRequest.status == "APPROVED")
        .scalar()
    )
    rejected_topups_amount = (
        db.query(func.coalesce(func.sum(TopUpRequest.amount), 0))
        .filter(TopUpRequest.status == "REJECTED")
        .scalar()
    )
    pending_topups_amount = (
        db.query(func.coalesce(func.sum(TopUpRequest.amount), 0))
        .filter(TopUpRequest.status == "PENDING")
        .scalar()
    )

    return {
        "total_orders": total_orders,
        "waiting_orders": waiting_orders,
        "active_orders": waiting_orders,
        "completed_orders": completed_orders,
        "total_revenue": float(total_revenue) if total_revenue else 0.0,
        "total_users": total_users,
        "total_couriers": total_couriers,
        "online_couriers": online_couriers,
        "pending_topups": pending_topups_count,
        "approved_topups_count": approved_topups_count,
        "rejected_topups_count": rejected_topups_count,
        "approved_topups_amount": float(approved_topups_amount or 0),
        "rejected_topups_amount": float(rejected_topups_amount or 0),
        "pending_topups_amount": float(pending_topups_amount or 0),
        # Today's metrics
        "total_orders_today": total_orders_today,
        "canceled_orders_today": canceled_orders_today,
        "delivered_orders_today": delivered_orders_today,
        "revenue_today": float(revenue_today) if revenue_today else 0.0,
    }

@router.get("/stats/{stat_date}")
def date_stats(
    stat_date: str,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    """Get statistics for a specific date (YYYY-MM-DD)"""
    from datetime import datetime
    
    try:
        target_date = datetime.strptime(stat_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    
    # Date range for the target date (00:00 to 23:59)
    from datetime import datetime, time
    day_start = datetime.combine(target_date, time.min)
    day_end = datetime.combine(target_date, time.max)
    
    total_orders = (
        db.query(func.count(Order.id))
        .filter(Order.created_at >= day_start, Order.created_at <= day_end, Order.enterprise_id == None)
        .scalar()
    )
    
    canceled_orders = (
        db.query(func.count(Order.id))
        .filter(
            Order.created_at >= day_start,
            Order.created_at <= day_end,
            Order.status.in_(["CANCELED", "CANCELLED"])
        )
        .scalar()
    )
    
    delivered_orders = (
        db.query(func.count(Order.id))
        .filter(
            Order.created_at >= day_start,
            Order.created_at <= day_end,
            Order.status == "COMPLETED"
        )
        .scalar()
    )
    
    revenue = float(delivered_orders or 0) * TOTAL_SERVICE_FEE_PER_COMPLETED_ORDER
    
    return {
        "total_orders_today": total_orders,
        "canceled_orders_today": canceled_orders,
        "delivered_orders_today": delivered_orders,
        "revenue_today": float(revenue) if revenue else 0.0,
        "date": stat_date,
    }

@router.get("/topup-stats")
def topup_stats(
    range: str = "all",
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    """Get topup statistics filtered by date range.
    
    range options:
    - all: all-time stats
    - today: today's stats
    - 7days: last 7 days
    - 30days: last 30 days
    """
    from datetime import datetime, timedelta
    
    if range not in ["all", "today", "7days", "30days"]:
        raise HTTPException(status_code=400, detail="Invalid range. Use: all, today, 7days, 30days")
    
    # Determine the date filter
    date_filter = None
    if range == "today":
        date_filter = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    elif range == "7days":
        date_filter = datetime.now() - timedelta(days=7)
    elif range == "30days":
        date_filter = datetime.now() - timedelta(days=30)
    
    # Build queries with date filtering
    def get_count_and_sum(status, use_approved_at=True):
        query = db.query(TopUpRequest).filter(TopUpRequest.status == status)
        
        if date_filter:
            if use_approved_at and status != "PENDING":
                query = query.filter(TopUpRequest.approved_at >= date_filter)
            else:
                query = query.filter(TopUpRequest.created_at >= date_filter)
        
        count = query.count()
        total = float(
            db.query(func.coalesce(func.sum(TopUpRequest.amount), 0))
            .filter(TopUpRequest.status == status)
            .filter(
                TopUpRequest.approved_at >= date_filter if (date_filter and use_approved_at and status != "PENDING") 
                else TopUpRequest.created_at >= date_filter if date_filter 
                else True
            )
            .scalar()
        )
        return count, total
    
    approved_count, approved_amount = get_count_and_sum("APPROVED")
    rejected_count, rejected_amount = get_count_and_sum("REJECTED")
    pending_count, pending_amount = get_count_and_sum("PENDING", use_approved_at=False)
    
    return {
        "approved_topups_count": approved_count,
        "rejected_topups_count": rejected_count,
        "pending_topups_count": pending_count,
        "approved_topups_amount": approved_amount,
        "rejected_topups_amount": rejected_amount,
        "pending_topups_amount": pending_amount,
    }

@router.get("/commission")
def commission_report(
    percent: float = 10,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    completed = (
        db.query(func.coalesce(func.sum(Order.price), 0))
        .filter(Order.status == "COMPLETED")
        .scalar()
    )

    commission = completed * (percent / 100)

    return {
        "percent": percent,
        "total_completed_amount": float(completed),
        "commission_amount": float(commission),
    }


@router.get("/revenue-trend")
def revenue_trend(
    days: int = 7,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    if days < 1:
        raise HTTPException(status_code=400, detail="days must be >= 1")
    if days > 90:
        raise HTTPException(status_code=400, detail="days must be <= 90")

    start_date = (datetime.now() - timedelta(days=days - 1)).date()

    rows = (
        db.query(
            func.date(Order.created_at).label("day"),
            func.count(Order.id).label("orders_count"),
        )
        .filter(
            Order.status == "COMPLETED",
            func.date(Order.created_at) >= start_date,
        )
        .group_by(func.date(Order.created_at))
        .all()
    )

    completed_by_day: dict[str, int] = {
        str(row.day): int(row.orders_count or 0)
        for row in rows
    }

    result = []
    for i in range(days):
        current_day = start_date + timedelta(days=i)
        key = current_day.isoformat()
        orders_count = completed_by_day.get(key, 0)
        revenue = float(orders_count * TOTAL_SERVICE_FEE_PER_COMPLETED_ORDER)
        result.append(
            {
                "date": key,
                "revenue": revenue,
                "orders": orders_count,
            }
        )

    return result

@router.get("/users")
def all_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    users = db.query(User).offset(skip).limit(limit).all()

    result = []
    generated_any = False
    for u in users:
        had_unique_id = bool(u.unique_id)
        unique_id = _ensure_user_unique_id(u, db)
        if not had_unique_id and unique_id:
            generated_any = True

        total_orders = (
            db.query(func.count(Order.id))
            .filter(Order.courier_id == u.id)
            .scalar()
            if u.is_courier
            else db.query(func.count(Order.id)).filter(Order.user_id == u.id).scalar()
        )

        average_rating = (
            db.query(func.avg(CourierRating.rating))
            .filter(CourierRating.courier_id == u.id)
            .scalar()
            if u.is_courier
            else None
        )

        result.append(
            {
                "id": u.id,
                "unique_id": unique_id,
                "phone": u.phone,
                "name": u.name,
                "is_active": u.is_active,
                "is_online": u.is_online,
                "is_courier": u.is_courier,
                "is_admin": u.is_admin,
                "balance": float(u.balance),
                "total_orders": int(total_orders or 0),
                "average_rating": float(average_rating) if average_rating is not None else None,
                "created_at": u.created_at,
            }
        )

    if generated_any:
        db.commit()

    return result

@router.post("/users/{user_id}/block")
def block_user(
    user_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404)

    user.is_active = False
    db.commit()

    return {"message": "User blocked"}


@router.post("/users/{user_id}/unblock")
def unblock_user(
    user_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404)

    user.is_active = True
    db.commit()

    return {"message": "User unblocked"}

@router.post("/users/{user_id}/balance")
def adjust_balance(
    user_id: int,
    amount: float,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404)

    user.balance += amount
    db.add(
        Transaction(
            user_id=user.id,
            amount=amount,
            type="ADMIN_ADJUST",
        )
    )
    db.commit()

    return {"balance": float(user.balance)}

@router.post("/users/{user_id}/disable-courier")
def disable_courier(
    user_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404)

    user.is_courier = False
    db.commit()

    return {"message": "Courier role removed"}

@router.post("/users/{user_id}/make-admin")
def make_admin(
    user_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404)

    user.is_admin = True
    db.commit()

    return {"message": "User promoted to admin"}


@router.put("/users/{user_id}")
def update_user(
    user_id: int,
    payload: AdminUserUpdateRequest,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404)

    if payload.phone is not None and payload.phone != user.phone:
        duplicate = db.query(User).filter(User.phone == payload.phone, User.id != user_id).first()
        if duplicate:
            raise HTTPException(status_code=400, detail="Phone already in use")
        user.phone = payload.phone

    if payload.name is not None:
        user.name = payload.name

    if payload.is_active is not None:
        user.is_active = payload.is_active

    if payload.role is not None:
        if payload.role == "admin":
            user.is_admin = True
            user.is_courier = False
        elif payload.role == "courier":
            user.is_admin = False
            user.is_courier = True
        else:
            user.is_admin = False
            user.is_courier = False

    db.commit()
    db.refresh(user)

    return {
        "id": user.id,
        "unique_id": user.unique_id,
        "phone": user.phone,
        "name": user.name,
        "is_active": user.is_active,
        "is_online": user.is_online,
        "is_courier": user.is_courier,
        "is_admin": user.is_admin,
        "balance": float(user.balance),
        "created_at": user.created_at,
    }


@router.delete("/users/{user_id}")
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    if admin.id == user_id:
        raise HTTPException(status_code=400, detail="You cannot delete yourself")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404)

    # Orders created by this user must be deleted because user_id is non-nullable.
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

    # Clean references where this user appears in other entities.
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

    # Preserve chats when possible by nullifying participant references.
    db.query(ChatRoom).filter(ChatRoom.user_id == user_id).update({ChatRoom.user_id: None}, synchronize_session=False)
    db.query(ChatRoom).filter(ChatRoom.courier_id == user_id).update({ChatRoom.courier_id: None}, synchronize_session=False)
    db.query(ChatRoom).filter(ChatRoom.admin_id == user_id).update({ChatRoom.admin_id: None}, synchronize_session=False)

    # Keep other users' orders, but detach deleted courier.
    db.query(Order).filter(Order.courier_id == user_id).update({Order.courier_id: None}, synchronize_session=False)

    db.query(TopUpRequest).filter(TopUpRequest.user_id == user_id).update({TopUpRequest.user_id: None}, synchronize_session=False)
    db.query(TopUpRequest).filter(TopUpRequest.approved_by_admin_id == user_id).update(
        {TopUpRequest.approved_by_admin_id: None}, synchronize_session=False
    )

    db.delete(user)
    db.commit()

    return {"message": "User deleted", "user_id": user_id}

@router.post("/users/{user_id}/change-password")
def admin_change_user_password(
    user_id: int,
    new_password: str,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    """Admin changes a user's password directly"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    from app.core.security import hash_password
    user.hashed_password = hash_password(new_password)
    db.commit()

    return {"message": "Password changed successfully", "user_id": user_id}

@router.post("/users/{user_id}/remove-admin")
def remove_admin(
    user_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404)

    user.is_admin = False
    db.commit()

    return {"message": "Admin role removed"}

@router.get("/users/{user_id}")
def user_detail(
    user_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404)

    unique_id = _ensure_user_unique_id(user, db)
    db.commit()

    total_orders = (
        db.query(func.count(Order.id))
        .filter(Order.courier_id == user.id)
        .scalar()
        if user.is_courier
        else db.query(func.count(Order.id)).filter(Order.user_id == user.id).scalar()
    )

    average_rating = (
        db.query(func.avg(CourierRating.rating))
        .filter(CourierRating.courier_id == user.id)
        .scalar()
        if user.is_courier
        else None
    )

    completed_orders = (
        db.query(func.count(Order.id))
        .filter(Order.courier_id == user.id, Order.status == "COMPLETED")
        .scalar()
        if user.is_courier
        else db.query(func.count(Order.id)).filter(Order.user_id == user.id, Order.status == "COMPLETED").scalar()
    )

    recent_orders = (
        db.query(Order)
        .filter(Order.courier_id == user.id)
        .order_by(Order.created_at.desc())
        .limit(10)
        .all()
        if user.is_courier
        else db.query(Order)
        .filter(Order.user_id == user.id)
        .order_by(Order.created_at.desc())
        .limit(10)
        .all()
    )

    recent_ratings = (
        db.query(CourierRating)
        .filter(CourierRating.courier_id == user.id)
        .order_by(CourierRating.created_at.desc())
        .limit(10)
        .all()
        if user.is_courier
        else []
    )

    return {
        "id": user.id,
        "unique_id": unique_id,
        "phone": user.phone,
        "name": user.name,
        "is_active": user.is_active,
        "is_online": user.is_online,
        "is_courier": user.is_courier,
        "is_admin": user.is_admin,
        "balance": float(user.balance),
        "total_orders": int(total_orders or 0),
        "completed_orders": int(completed_orders or 0),
        "average_rating": float(average_rating) if average_rating is not None else None,
        "created_at": user.created_at,
        "recent_orders": [
            {
                "id": o.id,
                "status": o.status,
                "price": float(o.price),
                "created_at": o.created_at,
                "from_address": o.from_address,
                "to_address": o.to_address,
            }
            for o in recent_orders
        ],
        "recent_ratings": [
            {
                "order_id": r.order_id,
                "rating": r.rating,
                "comment": r.comment,
                "created_at": r.created_at,
            }
            for r in recent_ratings
        ],
    }



@router.post("/orders/{order_id}/force-cancel")
def force_cancel_order(
    order_id: int,
    refund_user: bool = True,
    payout_courier: bool = False,
    note: str | None = None,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404)

    # Акча логикасы
    if refund_user:
        user = db.query(User).filter(User.id == order.user_id).first()
        refund(db, user, order.id, USER_ORDER_SERVICE_FEE)

    if payout_courier and order.courier_id:
        courier = db.query(User).filter(User.id == order.courier_id).first()
        payout(db, courier, order.id, COURIER_ORDER_SERVICE_FEE)

    apply_status_change(
        db=db,
        order=order,
        new_status="CANCELLED",
        actor_user_id=admin.id,
        enforce_transition=False,
    )
    order.admin_note = note
    db.commit()

    return {
        "message": "Order force cancelled by admin",
        "order_id": order.id,
    }

@router.post("/orders/{order_id}/reassign-courier")
def reassign_courier(
    order_id: int,
    new_courier_id: int,
    note: str | None = None,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404)

    courier = db.query(User).filter(
        User.id == new_courier_id,
        User.is_courier == True,
        User.is_active == True,
    ).first()
    if not courier:
        raise HTTPException(status_code=400, detail="Invalid courier")

    order.courier_id = courier.id
    apply_status_change(
        db=db,
        order=order,
        new_status="ACCEPTED",
        actor_user_id=admin.id,
        enforce_transition=False,
    )
    order.admin_note = note
    db.commit()

    return {"message": "Courier reassigned"}


@router.post("/orders/{order_id}/force-status")
def force_status(
    order_id: int,
    new_status: str,
    note: str | None = None,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404)

    apply_status_change(
        db=db,
        order=order,
        new_status=new_status,
        actor_user_id=admin.id,
        enforce_transition=False,
    )
    order.admin_note = note
    db.commit()

    return {
        "message": "Order status updated by admin",
        "status": new_status,
    }

@router.get("/orders/{order_id}")
def admin_order_detail(
    order_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404)

    status_logs = (
        db.query(OrderStatusLog)
        .filter(OrderStatusLog.order_id == order.id)
        .order_by(OrderStatusLog.created_at.desc())
        .all()
    )

    return {
        "id": order.id,
        "category": order.category,
        "description": order.description,
        "from_address": order.from_address,
        "to_address": order.to_address,
        "distance_km": float(order.distance_km),
        "status": order.status,
        "price": float(order.price),
        "user_id": order.user_id,
        "user_phone": order.user.phone if order.user else None,
        "courier_id": order.courier_id,
        "courier_phone": order.courier.phone if order.courier else None,
        "verification_code": order.verification_code,
        "hidden_for_user": order.hidden_for_user,
        "hidden_for_courier": order.hidden_for_courier,
        "admin_note": order.admin_note,
        "created_at": order.created_at,
        "status_audit": [
            {
                "actor_user_id": log.actor_user_id,
                "from_status": log.from_status,
                "to_status": log.to_status,
                "at": log.created_at,
            }
            for log in status_logs
        ],
    }


@router.delete("/orders/{order_id}")
def delete_order(
    order_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404)

    chat_ids = [row[0] for row in db.query(ChatRoom.id).filter(ChatRoom.order_id == order_id).all()]
    if chat_ids:
        db.query(Message).filter(Message.chat_id.in_(chat_ids)).delete(synchronize_session=False)

    db.query(ChatRoom).filter(ChatRoom.order_id == order_id).delete(synchronize_session=False)
    db.query(OrderStatusLog).filter(OrderStatusLog.order_id == order_id).delete(synchronize_session=False)
    db.query(CourierRating).filter(CourierRating.order_id == order_id).delete(synchronize_session=False)
    db.query(UserRating).filter(UserRating.order_id == order_id).delete(synchronize_session=False)
    db.query(Transaction).filter(Transaction.order_id == order_id).delete(synchronize_session=False)

    db.delete(order)
    db.commit()
    return {"message": "Order deleted from database", "order_id": order_id}


@router.get("/topups")
def pending_topups(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    reqs = (
        db.query(TopUpRequest)
        .filter(TopUpRequest.status == "PENDING")
        .order_by(TopUpRequest.created_at)
        .offset(skip)
        .limit(limit)
        .all()
    )

    return [
        {
            "id": r.id,
            "user_id": r.user_id,
            "unique_id": r.unique_id,
            "telegram_username": r.telegram_username,
            "amount": float(r.amount),
            "screenshot_file_id": r.screenshot_file_id,
            "created_at": r.created_at,
        }
        for r in reqs
    ]


# Telegram Bot Top-up Approval Endpoints
@router.get("/topup-requests/pending")
def get_pending_topup_requests(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    """Get all pending top-up requests from Telegram bot"""
    requests = (
        db.query(TopUpRequest)
        .filter(TopUpRequest.status == "PENDING")
        .order_by(TopUpRequest.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    
    result = []
    for req in requests:
        # Get user info by unique_id
        user = db.query(User).filter(User.unique_id == req.unique_id).first()
        
        result.append({
            "id": req.id,
            "unique_id": req.unique_id,
            "user_id": user.id if user else None,
            "user_name": user.name if user else "Unknown",
            "user_phone": user.phone if user else "Unknown",
            "telegram_username": req.telegram_username,
            "telegram_user_id": req.telegram_user_id,
            "amount": float(req.amount),
            "screenshot_file_id": req.screenshot_file_id,
            "status": req.status,
            "created_at": req.created_at,
        })
    
    return result


@router.get("/topup-requests/history")
def get_topup_history(
    skip: int = 0,
    limit: int = 100,
    status: str | None = None,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    """Get approved/rejected top-up requests history."""
    query = db.query(TopUpRequest)

    if status:
        query = query.filter(TopUpRequest.status == status.upper())
    else:
        query = query.filter(TopUpRequest.status.in_(["APPROVED", "REJECTED"]))

    requests = (
        query.order_by(TopUpRequest.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    result = []
    for req in requests:
        user = db.query(User).filter(User.unique_id == req.unique_id).first()
        result.append(
            {
                "id": req.id,
                "unique_id": req.unique_id,
                "user_id": user.id if user else req.user_id,
                "user_name": user.name if user else "Unknown",
                "user_phone": user.phone if user else "Unknown",
                "telegram_username": req.telegram_username,
                "telegram_user_id": req.telegram_user_id,
                "amount": float(req.amount),
                "screenshot_file_id": req.screenshot_file_id,
                "status": req.status,
                "admin_note": req.admin_note,
                "approved_at": req.approved_at,
                "created_at": req.created_at,
            }
        )

    return result


@router.get("/topup-requests/{request_id}/screenshot")
def open_topup_screenshot(
    request_id: int,
    db: Session = Depends(get_db),
    admin=Depends(require_admin),
):
    """Return Telegram-hosted screenshot URL for this top-up request."""
    topup_req = db.query(TopUpRequest).filter(TopUpRequest.id == request_id).first()
    if not topup_req:
        raise HTTPException(status_code=404, detail="Top-up request not found")

    file_url = _resolve_telegram_file_url(topup_req.screenshot_file_id)
    return {"file_url": file_url}


@router.post("/topup-requests/{request_id}/approve")
def approve_topup_request(
    request_id: int,
    admin_note: str = None,
    db: Session = Depends(get_db),
    current_admin=Depends(require_admin),
):
    """Approve a top-up request and credit user's balance"""
    # Get the request
    topup_req = db.query(TopUpRequest).filter(TopUpRequest.id == request_id).first()
    if not topup_req:
        raise HTTPException(status_code=404, detail="Top-up request not found")
    
    if topup_req.status != "PENDING":
        raise HTTPException(status_code=400, detail=f"Request already {topup_req.status}")
    
    # Find user by unique_id
    user = db.query(User).filter(User.unique_id == topup_req.unique_id).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"User with unique_id {topup_req.unique_id} not found")
    
    # Update balance
    topup(db, user, float(topup_req.amount))
    
    # Update request status
    topup_req.status = "APPROVED"
    topup_req.user_id = user.id
    topup_req.approved_by_admin_id = current_admin.id
    topup_req.approved_at = datetime.now()
    if admin_note:
        topup_req.admin_note = admin_note
    
    db.commit()

    approval_text = (
        f"✅ Топап тастыкталды\n"
        f"Жеке номер: {topup_req.unique_id}\n"
        f"Сумма: {float(topup_req.amount)} сом\n"
        f"Жаңы баланс: {float(user.balance)} сом"
    )
    _send_telegram_message(topup_req.telegram_user_id, approval_text)
    
    return {
        "message": "Top-up request approved",
        "user_id": user.id,
        "unique_id": user.unique_id,
        "amount": float(topup_req.amount),
        "new_balance": float(user.balance),
    }


@router.post("/topup-requests/{request_id}/reject")
def reject_topup_request(
    request_id: int,
    admin_note: str,
    db: Session = Depends(get_db),
    current_admin=Depends(require_admin),
):
    """Reject a top-up request"""
    # Get the request
    topup_req = db.query(TopUpRequest).filter(TopUpRequest.id == request_id).first()
    if not topup_req:
        raise HTTPException(status_code=404, detail="Top-up request not found")
    
    if topup_req.status != "PENDING":
        raise HTTPException(status_code=400, detail=f"Request already {topup_req.status}")
    
    # Update request status
    topup_req.status = "REJECTED"
    topup_req.approved_by_admin_id = current_admin.id
    topup_req.approved_at = datetime.now()
    topup_req.admin_note = admin_note
    
    db.commit()

    rejection_text = (
        f"❌ Топап четке кагылды\n"
        f"Жеке номер: {topup_req.unique_id}\n"
        f"Сумма: {float(topup_req.amount)} сом\n"
        f"Себеби: {admin_note}"
    )
    _send_telegram_message(topup_req.telegram_user_id, rejection_text)
    
    return {
        "message": "Top-up request rejected",
        "request_id": request_id,
        "admin_note": admin_note,
    }
