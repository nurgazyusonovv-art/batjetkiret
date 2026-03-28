import asyncio

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, status
from jose import JWTError, jwt
from sqlalchemy import func, or_
from sqlalchemy.orm import Session
from decimal import Decimal
from app.api.deps import get_db, get_current_user
from app.core.database import SessionLocal
from app.models.order import Order
from app.models.intercity_city import IntercityCity
from app.models.chat import ChatRoom
from app.models.message import Message
from app.models.order_status_log import OrderStatusLog
from app.models.rating import CourierRating
from app.models.transaction import Transaction
from app.models.user import User
from app.models.user_rating import UserRating
from app.schemas.order import OrderCreateRequest, OrderResponse
from app.core.config import settings
from app.services.pricing import calculate_price
from app.services.wallet import charge_platform_fee
from app.services.order_status import apply_status_change

router = APIRouter(prefix="/orders", tags=["Orders"])

MIN_BALANCE_TO_CREATE_ORDER = Decimal("10")
USER_ORDER_SERVICE_FEE = Decimal("5")
COURIER_ORDER_SERVICE_FEE = Decimal("5")


def _normalize_order_status(raw_status: str) -> str:
    return {
        "WAITING_COURIER": "pending",
        "ACCEPTED": "accepted",
        "IN_TRANSIT": "in_transit",
        "ON_THE_WAY": "in_transit",
        "PICKED_UP": "picked_up",
        "COMPLETED": "completed",
        "DELIVERED": "delivered",
        "CANCELLED": "cancelled",
    }.get(raw_status, raw_status.lower())


def _get_user_from_ws_token(db: Session, token: str | None) -> User:
    if token is None or token.strip() == "":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")

    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except JWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc

    user = db.query(User).filter(User.id == int(user_id)).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid user")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is blocked")

    return user


def _build_orders_live_snapshot(db: Session, current_user: User) -> list[dict]:
    # Exclude hidden orders based on user role; dine_in orders are not shown in the app
    orders = (
        db.query(Order)
        .filter(
            Order.source != "dine_in",
            or_(
                # User sees their orders that aren't hidden for them
                (Order.user_id == current_user.id) & (Order.hidden_for_user == False),  # noqa: E712
                # Courier sees their orders that aren't hidden for them
                (Order.courier_id == current_user.id) & (Order.hidden_for_courier == False),  # noqa: E712
            )
        )
        .order_by(Order.created_at.desc())
        .all()
    )

    snapshot = []
    for order in orders:
        chat = (
            db.query(ChatRoom)
            .filter(ChatRoom.order_id == order.id, ChatRoom.type == "ORDER")
            .first()
        )

        unread_count = 0
        if chat is not None:
            unread_count = (
                db.query(Message)
                .filter(
                    Message.chat_id == chat.id,
                    Message.sender_id != current_user.id,
                    Message.is_read == False,  # noqa: E712
                )
                .count()
            )

        snapshot.append(
            {
                "id": order.id,
                "status": _normalize_order_status(order.status),
                "unread_count": unread_count,
                "created_at": order.created_at.isoformat() if order.created_at else None,
            }
        )

    return snapshot


@router.websocket("/ws/my")
async def orders_live_socket(websocket: WebSocket):
    db = SessionLocal()
    try:
        token = websocket.query_params.get("token")
        current_user = _get_user_from_ws_token(db, token)
    except HTTPException:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        db.close()
        return

    await websocket.accept()
    previous_signature = ""

    try:
        while True:
            snapshot = _build_orders_live_snapshot(db, current_user)
            signature = "|".join(
                f"{item['id']}:{item['status']}:{item['unread_count']}"
                for item in snapshot
            )

            if signature != previous_signature:
                await websocket.send_json(
                    {
                        "event": "orders_snapshot",
                        "orders": snapshot,
                    }
                )
                previous_signature = signature

            await asyncio.sleep(2)
    except WebSocketDisconnect:
        pass
    except Exception:
        try:
            await websocket.close(code=status.WS_1011_INTERNAL_ERROR)
        except Exception:
            pass
    finally:
        db.close()



@router.post("/", response_model=OrderResponse)
def create_order(
    data: OrderCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.balance <= MIN_BALANCE_TO_CREATE_ORDER:
        raise HTTPException(
            status_code=400,
            detail="Заказ түзүү үчүн баланста 10 сомдон көп болушу керек",
        )

    # Intercity orders use fixed city price; regular orders use distance-based price.
    if data.category == "intercity":
        if not data.intercity_city_id:
            raise HTTPException(status_code=400, detail="intercity_city_id is required for intercity orders")
        city = db.query(IntercityCity).filter(
            IntercityCity.id == data.intercity_city_id,
            IntercityCity.is_active == True,  # noqa: E712
        ).first()
        if not city:
            raise HTTPException(status_code=404, detail="City not found or inactive")
        price = float(city.price)
    else:
        price = calculate_price(data.distance_km)

    # Store fixed commission values (business rule: 5 som from user + 5 som from courier).
    user_commission = USER_ORDER_SERVICE_FEE
    courier_commission = COURIER_ORDER_SERVICE_FEE

    order = Order(
        user_id=current_user.id,
        enterprise_id=data.enterprise_id,
        intercity_city_id=data.intercity_city_id,
        category=data.category,
        description=data.description,
        from_address=data.from_address,
        to_address=data.to_address,
        from_latitude=data.from_latitude,
        from_longitude=data.from_longitude,
        to_latitude=data.to_latitude,
        to_longitude=data.to_longitude,
        distance_km=data.distance_km if data.category != "intercity" else 0,
        price=price,
        items_total=data.items_total,
        user_commission=user_commission,
        courier_commission=courier_commission,
        status="WAITING_COURIER",
        source="online",
        order_type="delivery",
    )

    db.add(order)
    db.flush()

    allow_without_balance = settings.DEBUG or settings.ALLOW_ORDER_WITHOUT_BALANCE
    try:
        charge_platform_fee(
            db,
            current_user,
            order.id,
            float(USER_ORDER_SERVICE_FEE),
            "SERVICE_FEE_USER",
        )
    except ValueError:
        if not allow_without_balance:
            db.rollback()
            raise HTTPException(
                status_code=400,
                detail="5 сом сервис акысы үчүн балансыңыз жетишсиз",
            )

    db.commit()
    db.refresh(order)

    return {
        "id": order.id,
        "price": float(order.price),
        "status": order.status,
        "enterprise_id": order.enterprise_id,
        "items_total": float(order.items_total) if order.items_total is not None else None,
        "from_latitude": float(order.from_latitude) if order.from_latitude is not None else None,
        "from_longitude": float(order.from_longitude) if order.from_longitude is not None else None,
        "to_latitude": float(order.to_latitude) if order.to_latitude is not None else None,
        "to_longitude": float(order.to_longitude) if order.to_longitude is not None else None,
    }

@router.get("/orders/{order_id}/courier-rating")
def courier_rating_for_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404)

    if current_user.id not in [order.user_id, order.courier_id]:
        raise HTTPException(status_code=403)

    avg = (
        db.query(func.coalesce(func.avg(CourierRating.rating), 0))
        .filter(CourierRating.courier_id == order.courier_id)
        .scalar()
    )

    return {
        "courier_id": order.courier_id,
        "average_rating": round(float(avg), 2),
    }

@router.get("/my")
def my_orders(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    orders = (
        db.query(Order)
        .filter(
            Order.user_id == current_user.id,
            Order.hidden_for_user == False,  # noqa: E712
            Order.source != "dine_in",
        )
        .order_by(Order.created_at.desc())
        .all()
    )

    result = []
    for o in orders:
        order_dict = {
            "id": o.id,
            "category": o.category,
            "from_address": o.from_address,
            "to_address": o.to_address,
            "from_latitude": float(o.from_latitude) if o.from_latitude is not None else None,
            "from_longitude": float(o.from_longitude) if o.from_longitude is not None else None,
            "to_latitude": float(o.to_latitude) if o.to_latitude is not None else None,
            "to_longitude": float(o.to_longitude) if o.to_longitude is not None else None,
            "description": o.description,
            "status": o.status,
            "price": float(o.price),
            "distance_km": o.distance_km,
            "courier_id": o.courier_id,
            "verification_code": o.verification_code,
            "created_at": o.created_at,
            "enterprise_id": o.enterprise_id,
            "items_total": float(o.items_total) if o.items_total is not None else None,
        }
        
        # Include courier info if assigned
        if o.courier_id:
            order_dict["courier"] = {
                "id": o.courier.id,
                "name": o.courier.name,
                "phone": o.courier.phone,
            }
        
        result.append(order_dict)
    
    return result


@router.get("/{order_id}/counterparty")
def get_counterparty_info(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Укук текшерүү
    if current_user.id not in [order.user_id, order.courier_id]:
        raise HTTPException(status_code=403, detail="Access denied")

    # Эгер колдонуучу болсо → курьерди көрөт
    if current_user.id == order.user_id:
        if not order.courier_id:
            return {"message": "Courier not assigned yet"}

        courier = db.query(User).filter(User.id == order.courier_id).first()

        return {
            "role": "courier",
            "id": courier.id,
            "name": courier.name,
            "phone": courier.phone,
            "call_url": f"tel:{courier.phone}",
            "whatsapp_url": f"https://wa.me/{courier.phone}",
        }

    # Эгер курьер болсо → колдонуучуну көрөт
    if current_user.id == order.courier_id:
        user = db.query(User).filter(User.id == order.user_id).first()

        return {
            "role": "user",
            "id": user.id,
            "name": user.name,
            "phone": user.phone,
            "call_url": f"tel:{user.phone}",
            "whatsapp_url": f"https://wa.me/{user.phone}",
        }


@router.get("/{order_id}")
def get_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404)

    if order.user_id != current_user.id and order.courier_id != current_user.id:
        raise HTTPException(status_code=403)

    result = {
        "id": order.id,
        "status": order.status,
        "price": float(order.price),
        "category": order.category,
        "description": order.description,
        "from_address": order.from_address,
        "to_address": order.to_address,
        "from_latitude": float(order.from_latitude) if order.from_latitude is not None else None,
        "from_longitude": float(order.from_longitude) if order.from_longitude is not None else None,
        "to_latitude": float(order.to_latitude) if order.to_latitude is not None else None,
        "to_longitude": float(order.to_longitude) if order.to_longitude is not None else None,
        "distance_km": float(order.distance_km) if order.distance_km is not None else None,
        "created_at": order.created_at,
        "enterprise_id": order.enterprise_id,
        "items_total": float(order.items_total) if order.items_total is not None else None,
    }

    # Only show verification code to the order owner when status is DELIVERED
    if order.user_id == current_user.id and order.status == "DELIVERED":
        result["verification_code"] = order.verification_code

    if order.courier_id and order.courier:
        result["courier_name"] = order.courier.name
        result["courier_phone"] = order.courier.phone
        result["courier_latitude"] = order.courier.current_latitude
        result["courier_longitude"] = order.courier.current_longitude

    if order.enterprise_id:
        from app.models.enterprise import Enterprise
        ent = db.query(Enterprise).filter(Enterprise.id == order.enterprise_id).first()
        if ent:
            result["enterprise_name"] = ent.name

    return result


@router.get("/{order_id}/status-audit")
def get_order_status_audit(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if current_user.id not in [order.user_id, order.courier_id]:
        raise HTTPException(status_code=403, detail="Access denied")

    logs = (
        db.query(OrderStatusLog)
        .filter(OrderStatusLog.order_id == order.id)
        .order_by(OrderStatusLog.created_at)
        .all()
    )

    return {
        "order_id": order.id,
        "status_audit": [
            {
                "actor_user_id": log.actor_user_id,
                "from_status": log.from_status,
                "to_status": log.to_status,
                "at": log.created_at,
            }
            for log in logs
        ],
    }

@router.get("/orders/{order_id}/user-rating")
def user_rating_for_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404)

    if current_user.id not in [order.user_id, order.courier_id]:
        raise HTTPException(status_code=403)

    from sqlalchemy import func

    avg = (
        db.query(func.coalesce(func.avg(UserRating.rating), 0))
        .filter(UserRating.target_user_id == order.user_id)
        .scalar()
    )

    return {
        "user_id": order.user_id,
        "average_rating": round(float(avg), 2),
    }

@router.patch("/{order_id}")
def update_order(
    order_id: int,
    data: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update order — only allowed when status is WAITING_COURIER."""
    from pydantic import BaseModel
    from typing import Optional

    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    if order.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Forbidden")
    if order.status != "WAITING_COURIER":
        raise HTTPException(status_code=400, detail="Курьер дайындалган заказды өзгөртүүгө болбойт")

    allowed = {"description", "from_address", "to_address",
               "from_latitude", "from_longitude", "to_latitude", "to_longitude",
               "distance_km"}
    for field, value in data.items():
        if field in allowed:
            setattr(order, field, value)

    # Recalculate price if distance changed
    if "distance_km" in data and data["distance_km"] is not None:
        from app.services.pricing import calculate_price
        order.price = calculate_price(float(data["distance_km"]))

    db.commit()
    db.refresh(order)
    return {"id": order.id, "message": "Updated", "price": float(order.price)}


@router.post("/{order_id}/cancel")
def cancel_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Колдонуучу гана өз заказын
    if order.user_id != current_user.id:
        raise HTTPException(status_code=403)

    # Колдонуучу күтүүдө болгон заказды гана отмена кыла алат
    if order.status != "WAITING_COURIER":
        raise HTTPException(
            status_code=400,
            detail="Күтүүдө болгон заказды гана жокко чыгара аласыз",
        )

    apply_status_change(
        db=db,
        order=order,
        new_status="CANCELLED",
        actor_user_id=current_user.id,
    )
    db.commit()
    return {"message": "Order cancelled"}

@router.delete("/{order_id}")
def delete_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()

    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Колдонуучу өз заказын гана өчүрөт
    if order.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Forbidden")

    # Статус текшерүү: аяктаган же жокко чыгарылган заказды гана өчүрө алат
    if order.status not in ["CANCELLED", "COMPLETED"]:
        raise HTTPException(
            status_code=400,
            detail="Аяктаган же жокко чыгарылган заказдарды гана өчүрө аласыз",
        )

    # Soft delete - колдонуучу үчүн гана жашыруу
    order.hidden_for_user = True
    db.commit()

    return {"message": "Order deleted"}


@router.delete("/my/all")
def delete_all_my_orders(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete all completed and cancelled orders for current user"""
    # Өчүрүүгө жарактуу заказдарды табуу
    orders_to_delete = (
        db.query(Order)
        .filter(
            Order.user_id == current_user.id,
            Order.status.in_(["CANCELLED", "COMPLETED"]),
            Order.hidden_for_user == False,  # noqa: E712
        )
        .all()
    )

    if not orders_to_delete:
        return {"message": "No orders to delete", "deleted_count": 0}

    deleted_count = 0
    for order in orders_to_delete:
        # Soft delete - колдонуучу үчүн гана жашыруу
        order.hidden_for_user = True
        deleted_count += 1

    db.commit()

    return {
        "message": f"{deleted_count} заказ тазаланды",
        "deleted_count": deleted_count,
    }