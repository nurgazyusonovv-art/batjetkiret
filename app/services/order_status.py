from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.order import Order
from app.models.order_status_log import OrderStatusLog


ALLOWED_STATUSES = {
    "WAITING_COURIER",
    "PREPARING",
    "READY",
    "ACCEPTED",
    "ON_THE_WAY",
    "PICKED_UP",
    "DELIVERED",
    "COMPLETED",
    "CANCELLED",
}


ALLOWED_TRANSITIONS = {
    # WAITING_COURIER can go back to PREPARING/READY for enterprise local orders
    "WAITING_COURIER": {"PREPARING", "READY", "ACCEPTED", "COMPLETED", "CANCELLED"},
    # PREPARING → WAITING_COURIER: enterprise local-delivery order is ready for pickup
    "PREPARING": {"READY", "WAITING_COURIER", "ACCEPTED", "COMPLETED", "CANCELLED"},
    # READY → WAITING_COURIER: dine-in/local order marked ready then routed to courier
    "READY": {"WAITING_COURIER", "ACCEPTED", "COMPLETED", "CANCELLED"},
    "ACCEPTED": {"PREPARING", "READY", "ON_THE_WAY", "PICKED_UP", "DELIVERED", "COMPLETED", "CANCELLED", "WAITING_COURIER"},
    "PICKED_UP": {"ON_THE_WAY", "DELIVERED", "COMPLETED", "CANCELLED", "WAITING_COURIER"},
    "ON_THE_WAY": {"DELIVERED", "COMPLETED", "CANCELLED"},
    "DELIVERED": {"COMPLETED"},
    "COMPLETED": set(),
    "CANCELLED": set(),
}

TERMINAL_STATUSES = {"COMPLETED", "CANCELLED"}


def ensure_valid_status(status: str) -> None:
    if status not in ALLOWED_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid status")


def ensure_transition(current_status: str, new_status: str) -> None:
    ensure_valid_status(new_status)
    if current_status not in ALLOWED_TRANSITIONS:
        raise HTTPException(status_code=400, detail="Invalid current status")

    if new_status not in ALLOWED_TRANSITIONS[current_status]:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot change status from {current_status} to {new_status}",
        )


def ensure_not_terminal(current_status: str) -> None:
    if current_status in TERMINAL_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot change terminal order status: {current_status}",
        )


_USER_PUSH_MESSAGES = {
    "ACCEPTED":   ("✅ Заказыңыз кабыл алынды", "Курьер жолго чыгууга даярданып жатат"),
    "ON_THE_WAY": ("🚴 Курьер жолдо!", "Заказыңыз жеткирүүдө"),
    "DELIVERED":  ("📦 Жеткирилди!", "Заказыңыз жеткирилди. Рахмат!"),
    "COMPLETED":  ("✅ Аяктады", "Заказыңыз ийгиликтүү аяктады"),
    "CANCELLED":  ("❌ Жокко чыгарылды", "Заказыңыз жокко чыгарылды"),
}


def apply_status_change(
    db: Session,
    order: Order,
    new_status: str,
    actor_user_id: int,
    enforce_transition: bool = True,
) -> None:
    current_status = order.status

    if current_status == new_status:
        return

    if enforce_transition:
        ensure_not_terminal(current_status)
        ensure_transition(current_status, new_status)
    else:
        ensure_valid_status(new_status)

    db.add(
        OrderStatusLog(
            order_id=order.id,
            actor_user_id=actor_user_id,
            from_status=current_status,
            to_status=new_status,
        )
    )
    order.status = new_status

    # Push notifications to customer on key status changes
    if new_status in _USER_PUSH_MESSAGES and order.user_id:
        title, body = _USER_PUSH_MESSAGES[new_status]
        push_data = {"order_id": str(order.id), "status": new_status, "type": "order_status"}
        push_body = f"Заказ #{order.id} — {body}"

        # FCM push to mobile user
        try:
            from app.models.user import User
            from app.services import fcm as fcm_service
            user = db.query(User).filter(User.id == order.user_id).first()
            if user:
                fcm_service.send_push_to_user(user, title=title, body=push_body, data=push_data)
        except Exception:
            pass

        # Web Push to customer (Flutter web)
        try:
            from app.services.web_push import notify_user
            notify_user(
                db,
                user_id=order.user_id,
                title=title,
                body=push_body,
                data=push_data,
            )
        except Exception:
            pass
