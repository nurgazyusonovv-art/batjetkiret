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
    "DELIVERED",
    "COMPLETED",
    "CANCELLED",
}


ALLOWED_TRANSITIONS = {
    "WAITING_COURIER": {"ACCEPTED", "CANCELLED"},
    "PREPARING": {"READY", "CANCELLED"},
    "READY": {"ACCEPTED", "CANCELLED"},
    "ACCEPTED": {"PREPARING", "ON_THE_WAY", "CANCELLED", "WAITING_COURIER"},
    "ON_THE_WAY": {"DELIVERED", "COMPLETED"},
    "DELIVERED": {"COMPLETED"},
    "COMPLETED": set(),
    "CANCELLED": set(),
}


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

    # Web Push to customer (Flutter web) on key status changes
    if new_status in _USER_PUSH_MESSAGES and order.user_id:
        try:
            from app.services.web_push import notify_user
            title, body = _USER_PUSH_MESSAGES[new_status]
            notify_user(
                db,
                user_id=order.user_id,
                title=title,
                body=f"Заказ #{order.id} — {body}",
                data={"order_id": order.id, "status": new_status, "type": "order_status"},
            )
        except Exception:
            pass