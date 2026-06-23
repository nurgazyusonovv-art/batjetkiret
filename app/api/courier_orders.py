from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from decimal import Decimal
from datetime import datetime, timedelta

from app.api.deps import get_db, get_current_user
from app.models.order import Order
from app.models.order_payment import OrderPayment
from app.models.enterprise import Enterprise
from app.models.user import User
from app.models.chat import ChatRoom
from app.models.transaction import Transaction
from app.services.wallet import charge_platform_fee, hold_amount, settle_hold, release_hold, _open_hold
from app.services.order_status import apply_status_change
from app.core.limiter import limiter
from app.models.setting import Setting
from app.api.admin import get_courier_cancel_penalty

router = APIRouter(prefix="/courier/orders", tags=["Courier Orders"])

COURIER_ORDER_SERVICE_FEE_DEFAULT = Decimal("5")
ACTIVE_COURIER_STATUSES = (
    "ACCEPTED",
    "PREPARING",
    "READY",
    "PICKED_UP",
    "ON_THE_WAY",
    "IN_TRANSIT",
    "DELIVERED",
)


def _local_day_start_utc(days_ago: int = 0) -> datetime:
    """Naive-UTC instant matching local (UTC+6) midnight `days_ago` days back.

    Transaction.created_at is stored as naive UTC; to bucket by the local business
    day we shift to local time, take the day boundary, then convert back to UTC.
    """
    import os
    tz_offset = int(os.getenv("TZ_OFFSET_HOURS", "6"))
    local_now = datetime.utcnow() + timedelta(hours=tz_offset)
    local_midnight = local_now.replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=days_ago)
    return local_midnight - timedelta(hours=tz_offset)


def _get_service_fee(db) -> Decimal:
    row = db.query(Setting).filter(Setting.key == "courier_service_fee").first()
    if row:
        try:
            return Decimal(str(float(row.value)))
        except Exception:
            pass
    return COURIER_ORDER_SERVICE_FEE_DEFAULT


def _enterprise_name_map(db: Session, orders: list[Order]) -> dict[int, str]:
    enterprise_ids = {o.enterprise_id for o in orders if o.enterprise_id is not None}
    if not enterprise_ids:
        return {}
    enterprises = db.query(Enterprise).filter(Enterprise.id.in_(enterprise_ids)).all()
    return {e.id: e.name for e in enterprises}


def _active_courier_order(db: Session, courier_id: int) -> Order | None:
    return (
        db.query(Order)
        .filter(
            Order.courier_id == courier_id,
            Order.status.in_(ACTIVE_COURIER_STATUSES),
            Order.hidden_for_courier == False,  # noqa: E712
        )
        .order_by(Order.created_at.desc())
        .first()
    )


def _charge_courier_service_fee(db: Session, courier: User, order_id: int):
    fee = _get_service_fee(db)
    try:
        charge_platform_fee(
            db,
            courier,
            order_id,
            float(fee),
            "SERVICE_FEE_COURIER",
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Заказды аяктоо үчүн курьер балансында {fee} сом болушу керек",
        ) from exc




@router.get("/my")
@limiter.limit("30/minute")
def my_courier_orders(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=403, detail="Not a courier")

    orders = (
        db.query(Order)
        .filter(
            Order.courier_id == current_user.id,
            Order.hidden_for_courier == False,  # noqa: E712
        )
        .order_by(Order.created_at.desc())
        .all()
    )

    enterprise_names = _enterprise_name_map(db, orders)
    result = []
    for o in orders:
        order_dict = {
            "id": o.id,
            "category": o.category,
            "description": o.description,
            "from_address": o.from_address,
            "to_address": o.to_address,
            "from_latitude": float(o.from_latitude) if o.from_latitude is not None else None,
            "from_longitude": float(o.from_longitude) if o.from_longitude is not None else None,
            "to_latitude": float(o.to_latitude) if o.to_latitude is not None else None,
            "to_longitude": float(o.to_longitude) if o.to_longitude is not None else None,
            "distance_km": float(o.distance_km),
            "price": float(o.price),
            "status": o.status,
            "created_at": o.created_at,
            "enterprise_id": o.enterprise_id,
            "enterprise_name": enterprise_names.get(o.enterprise_id) if o.enterprise_id else None,
        }
        
        # Include user info
        order_dict["user"] = {
            "id": o.user.id,
            "name": o.user.name,
            "phone": o.user.phone,
        }
        
        # Include courier info  
        if o.courier:
            order_dict["courier"] = {
                "id": o.courier.id,
                "name": o.courier.name,
                "phone": o.courier.phone,
            }
        
        result.append(order_dict)
    
    return result

@router.get("/available")
@limiter.limit("30/minute")
def available_orders(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=403, detail="Not a courier")

    if _active_courier_order(db, current_user.id):
        return []

    confirmed_enterprise_payments = (
        db.query(OrderPayment.order_id)
        .filter(OrderPayment.status == "confirmed")
    )
    orders = (
        db.query(Order)
        .filter(
            or_(
                # Regular (non-enterprise) orders: visible as soon as placed
                (Order.status == "WAITING_COURIER") & (Order.enterprise_id.is_(None)),
                # Enterprise orders: visible after enterprise confirmation or when marked ready.
                (
                    Order.enterprise_id.isnot(None)
                    & Order.courier_id.is_(None)
                    & or_(
                        Order.status.in_(["ACCEPTED", "READY"]),
                        (
                            (Order.status == "WAITING_COURIER")
                            & Order.id.in_(confirmed_enterprise_payments)
                        ),
                    )
                ),
            ),
            Order.category != "intercity",
        )
        .order_by(Order.created_at.desc())
        .all()
    )

    enterprise_names = _enterprise_name_map(db, orders)
    return [
        {
            "id": o.id,
            "category": o.category,
            "description": o.description,
            "from_address": o.from_address,
            "to_address": o.to_address,
            "from_latitude": float(o.from_latitude) if o.from_latitude is not None else None,
            "from_longitude": float(o.from_longitude) if o.from_longitude is not None else None,
            "to_latitude": float(o.to_latitude) if o.to_latitude is not None else None,
            "to_longitude": float(o.to_longitude) if o.to_longitude is not None else None,
            "distance_km": float(o.distance_km),
            "price": float(o.price),
            "status": o.status,
            "created_at": o.created_at,
            "enterprise_id": o.enterprise_id,
            "enterprise_name": enterprise_names.get(o.enterprise_id) if o.enterprise_id else None,
        }
        for o in orders
    ]

@router.post("/{order_id}/accept")
def accept_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=403, detail="Not a courier")

    # Reserve the service fee at acceptance — balance must cover it up front.
    fee = _get_service_fee(db)
    if (current_user.balance or Decimal("0")) < fee:
        raise HTTPException(
            status_code=400,
            detail=f"Заказ кабыл алуу үчүн балансыңызда {fee} сом болушу керек",
        )

    active_order = _active_courier_order(db, current_user.id)
    if active_order and active_order.id != order_id:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Сизде активдүү заказ #{active_order.id} бар. "
                "Жаңы заказ алуу үчүн алгач активдүү заказды аяктаңыз."
            ),
        )

    # Row-lock so two couriers can't accept the same order concurrently.
    order = (
        db.query(Order)
        .filter(Order.id == order_id)
        .with_for_update()
        .first()
    )
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    is_enterprise_available = order.status in ("ACCEPTED", "READY") and order.enterprise_id is not None and order.courier_id is None
    if order.status != "WAITING_COURIER" and not is_enterprise_available:
        raise HTTPException(status_code=409, detail="Order is not available")

    if order.courier_id is not None and order.courier_id != current_user.id:
        raise HTTPException(status_code=409, detail="Order already accepted")

    apply_status_change(
        db=db,
        order=order,
        new_status="ACCEPTED",
        actor_user_id=current_user.id,
    )
    order.courier_id = current_user.id

    existing_chat = (
        db.query(ChatRoom)
        .filter(ChatRoom.order_id == order.id, ChatRoom.type == "ORDER")
        .first()
    )
    if existing_chat is None:
        chat = ChatRoom(
            type="ORDER",
            order_id=order.id,
            user_id=order.user_id,
            courier_id=current_user.id,
        )
        db.add(chat)

    # Reserve (hold) the courier service fee now. If a hold already exists for this
    # order (re-accept of own order), skip. Rolls back with the rest on failure.
    if _open_hold(db, current_user.id, order.id) is None:
        try:
            hold_amount(db, current_user, order.id, float(fee))
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Заказ кабыл алуу үчүн балансыңызда {fee} сом болушу керек",
            )

    db.commit()

    return {
        "message": "Order accepted",
        "order_id": order.id,
    }

@router.post("/{order_id}/cancel")
def cancel_courier_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=403, detail="Not a courier")

    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Курьер өз кабыл алган заказын гана
    if order.courier_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your order")

    # Кабыл алынган же алып кеткен статусунда гана отмена кыла алат
    if order.status not in ("ACCEPTED", "PICKED_UP"):
        raise HTTPException(
            status_code=400,
            detail="Заказды алгандан кийин гана баш тарта аласыз",
        )

    # Release the reserved service fee first (order not completed), so the freed
    # balance can cover the penalty. On any error below, the whole tx rolls back.
    release_hold(db, current_user, order.id)

    # Пенальти: DB'дан окуп, балансынан кармоо
    penalty_amount = get_courier_cancel_penalty(db)
    if current_user.balance < penalty_amount:
        raise HTTPException(
            status_code=400,
            detail=f"Баш тартуу үчүн балансыңызда жетиштүү каражат жок ({penalty_amount} сом керек)",
        )

    current_user.balance -= penalty_amount
    if penalty_amount > 0:
        db.add(Transaction(
            user_id=current_user.id,
            order_id=order.id,
            amount=-penalty_amount,
            type="CANCEL_PENALTY",
        ))

    # Статусту WAITING_COURIER кайтаруу
    apply_status_change(
        db=db,
        order=order,
        new_status="WAITING_COURIER",
        actor_user_id=current_user.id,
    )
    order.courier_id = None

    db.commit()

    return {
        "message": f"Заказдан баш тарттыңыз. Балансыңыздан {penalty_amount} сом кармалды.",
        "penalty": float(penalty_amount),
    }

def _complete_courier_order(db: Session, courier: User, order_id: int) -> dict:
    """Idempotently complete a courier's order and charge the service fee once.

    Guards against double-charge if the completion endpoint is hit twice
    (retry / double-tap): if the order is already COMPLETED, returns without
    re-charging; if CANCELLED, rejects.
    """
    # Row-lock to serialize concurrent completion attempts.
    order = db.query(Order).filter(Order.id == order_id).with_for_update().first()
    if not order or order.courier_id != courier.id:
        raise HTTPException(status_code=404)

    if order.status == "COMPLETED":
        return {"message": "Order already completed"}
    if order.status == "CANCELLED":
        raise HTTPException(status_code=400, detail="Заказ жокко чыгарылган")

    apply_status_change(
        db=db,
        order=order,
        new_status="COMPLETED",
        actor_user_id=courier.id,
    )
    # Service fee was reserved (HOLD) at acceptance — just finalize it.
    # Legacy orders accepted before reservation existed have no hold → charge now.
    if not settle_hold(db, courier, order.id):
        _charge_courier_service_fee(db, courier, order.id)
    db.commit()
    return {"message": "Order completed"}


@router.post("/{order_id}/deliver")
def deliver_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=403)
    return _complete_courier_order(db, current_user, order_id)

@router.post("/{order_id}/start")
def start_delivery(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=403)

    order = db.query(Order).filter(Order.id == order_id).first()
    if not order or order.courier_id != current_user.id:
        raise HTTPException(status_code=404)

    apply_status_change(
        db=db,
        order=order,
        new_status="ON_THE_WAY",
        actor_user_id=current_user.id,
    )
    db.commit()

    return {"message": "Delivery started"}

@router.post("/{order_id}/delivered")
def mark_delivered(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Courier marks order as delivered and immediately completes it."""
    if not current_user.is_courier:
        raise HTTPException(status_code=403)
    return _complete_courier_order(db, current_user, order_id)


@router.post("/{order_id}/complete")
def complete_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Kept for backwards compatibility — same as /delivered."""
    if not current_user.is_courier:
        raise HTTPException(status_code=403)
    return _complete_courier_order(db, current_user, order_id)

@router.get("/stats")
@limiter.limit("30/minute")
def courier_statistics(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get courier performance statistics and earnings"""
    if not current_user.is_courier:
        raise HTTPException(status_code=403, detail="Not a courier")

    # Total completed orders
    total_completed = (
        db.query(func.count(Order.id))
        .filter(
            Order.courier_id == current_user.id,
            Order.status == "COMPLETED",
        )
        .scalar() or 0
    )

    # Total earnings (sum of delivery prices from completed orders)
    total_earnings = (
        db.query(func.sum(Order.price))
        .filter(
            Order.courier_id == current_user.id,
            Order.status == "COMPLETED",
        )
        .scalar() or Decimal("0")
    )

    # Total service fees paid
    total_fees = (
        db.query(func.sum(Transaction.amount))
        .filter(
            Transaction.user_id == current_user.id,
            Transaction.type == "SERVICE_FEE_COURIER",
        )
        .scalar() or Decimal("0")
    )
    # Fees are stored as negative, convert to positive for display
    total_fees = abs(total_fees)

    # Today's stats — local (UTC+6) midnight as a UTC instant matching created_at storage
    today_start = _local_day_start_utc(0)
    
    # Today completed orders (tracked by SERVICE_FEE_COURIER transaction time).
    today_completed_order_ids = (
        db.query(Transaction.order_id)
        .filter(
            Transaction.user_id == current_user.id,
            Transaction.type == "SERVICE_FEE_COURIER",
            Transaction.created_at >= today_start,
        )
        .all()
    )
    today_completed_order_ids = [oid[0] for oid in today_completed_order_ids if oid[0] is not None]
    
    today_completed = len(today_completed_order_ids)

    # Today earnings (sum of delivery prices from orders completed today)
    today_earnings = (
        db.query(func.sum(Order.price))
        .filter(
            Order.id.in_(today_completed_order_ids)
        )
        .scalar() or Decimal("0")
    ) if today_completed_order_ids else Decimal("0")

    # Active orders (assigned but not completed/cancelled)
    active_orders = (
        db.query(func.count(Order.id))
        .filter(
            Order.courier_id == current_user.id,
            Order.status.in_(["ACCEPTED", "IN_TRANSIT", "ON_THE_WAY", "PICKED_UP", "DELIVERED"]),
        )
        .scalar() or 0
    )

    return {
        "total_completed_orders": total_completed,
        "total_earnings": float(total_earnings),
        "total_service_fees": float(total_fees),
        "net_earnings": float(total_earnings - total_fees),
        "today_completed_orders": today_completed,
        "today_earnings": float(today_earnings),
        "active_orders": active_orders,
        "current_balance": float(current_user.balance),
    }
