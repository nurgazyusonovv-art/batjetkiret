from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func
from decimal import Decimal
import random
from datetime import datetime, timedelta

from app.api.deps import get_db, get_current_user
from app.models.order import Order
from app.models.user import User
from app.models.chat import ChatRoom
from app.models.transaction import Transaction
from app.services.wallet import charge_platform_fee
from app.services.order_status import apply_status_change
from app.core.limiter import limiter
from app.models.setting import Setting
from app.api.admin import get_courier_cancel_penalty

router = APIRouter(prefix="/courier/orders", tags=["Courier Orders"])

COURIER_ORDER_SERVICE_FEE_DEFAULT = Decimal("5")


def _get_service_fee(db) -> Decimal:
    row = db.query(Setting).filter(Setting.key == "courier_service_fee").first()
    if row:
        try:
            return Decimal(str(float(row.value)))
        except Exception:
            pass
    return COURIER_ORDER_SERVICE_FEE_DEFAULT


class CompleteOrderRequest(BaseModel):
    verification_code: str


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

    from sqlalchemy import or_
    orders = (
        db.query(Order)
        .filter(
            or_(
                # Regular (non-enterprise) orders: visible as soon as placed
                (Order.status == "WAITING_COURIER") & (Order.enterprise_id.is_(None)),
                # Enterprise orders: visible to couriers only when marked READY by the enterprise
                (Order.status == "READY") & (Order.enterprise_id.isnot(None)),
            ),
            Order.category != "intercity",
        )
        .order_by(Order.created_at.desc())
        .all()
    )

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

    if (current_user.balance or Decimal("0")) < Decimal("0"):
        raise HTTPException(
            status_code=400,
            detail="Балансыңыз терс. Заказ кабыл алуу үчүн алгач балансыңызды толуктаңыз",
        )

    order = (
        db.query(Order)
        .filter(Order.id == order_id)
        .first()
    )
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    is_enterprise_ready = order.status == "READY" and order.enterprise_id is not None
    if order.status != "WAITING_COURIER" and not is_enterprise_ready:
        raise HTTPException(status_code=409, detail="Order is not available")

    if order.courier_id is not None and order.courier_id != current_user.id:
        raise HTTPException(status_code=409, detail="Order already accepted")

    apply_status_change(
        db=db,
        order=order,
        new_status="PICKED_UP",
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

    # Пенальти: DB'дан окуп, балансынан кармоо
    penalty_amount = get_courier_cancel_penalty(db)
    if current_user.balance < penalty_amount:
        raise HTTPException(
            status_code=400,
            detail=f"Баш тартуу үчүн балансыңызда жетиштүү каражат жок ({penalty_amount} сом керек)",
        )

    current_user.balance -= penalty_amount

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

@router.post("/{order_id}/deliver")
def deliver_order(
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
        new_status="COMPLETED",
        actor_user_id=current_user.id,
    )
    # Do not add order price to courier balance on completion.
    _charge_courier_service_fee(db, current_user, order.id)

    db.commit()

    return {"message": "Order completed"}

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
    if not current_user.is_courier:
        raise HTTPException(status_code=403)

    order = db.query(Order).filter(Order.id == order_id).first()
    if not order or order.courier_id != current_user.id:
        raise HTTPException(status_code=404)

    # Generate 6-digit verification code
    verification_code = str(random.randint(100000, 999999))
    order.verification_code = verification_code

    apply_status_change(
        db=db,
        order=order,
        new_status="DELIVERED",
        actor_user_id=current_user.id,
    )
    db.commit()

    return {
        "message": "Order delivered",
        "verification_code": verification_code,
    }



@router.post("/{order_id}/complete")
def complete_order(
    order_id: int,
    request: CompleteOrderRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=403)

    order = db.query(Order).filter(Order.id == order_id).first()
    if not order or order.courier_id != current_user.id:
        raise HTTPException(status_code=404)

    # Verify the code
    if not order.verification_code:
        raise HTTPException(status_code=400, detail="Verification code not generated yet")
    
    if order.verification_code != request.verification_code:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    apply_status_change(
        db=db,
        order=order,
        new_status="COMPLETED",
        actor_user_id=current_user.id,
    )
    # Do not add order price to courier balance on completion.
    _charge_courier_service_fee(db, current_user, order.id)

    # Clear verification code after successful completion
    order.verification_code = None
    
    db.commit()

    return {"message": "Order completed"}

@router.post("/{order_id}/cancel")
def cancel_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order or order.user_id != current_user.id:
        raise HTTPException(status_code=404)

    apply_status_change(
        db=db,
        order=order,
        new_status="CANCELLED",
        actor_user_id=current_user.id,
    )
    db.commit()

    return {"message": "Order cancelled"}


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

    # Today's stats (from midnight)
    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    
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
