import logging

from sqlalchemy import exists
from sqlalchemy.orm import Session

from app.models.notification import Notification
from app.models.order import Order
from app.models.order_payment import OrderPayment
from app.models.user import User
from app.services import fcm as fcm_service


logger = logging.getLogger(__name__)

ACTIVE_COURIER_STATUSES = (
    "ACCEPTED",
    "PREPARING",
    "READY",
    "PICKED_UP",
    "ON_THE_WAY",
    "IN_TRANSIT",
    "DELIVERED",
)


def _is_available_to_couriers(db: Session, order: Order) -> bool:
    if order.courier_id is not None:
        return False
    if order.category == "intercity" or order.order_type == "dine_in":
        return False
    if order.enterprise_id is None:
        return order.status == "WAITING_COURIER"
    if order.status in {"ACCEPTED", "READY"}:
        return True
    if order.status != "WAITING_COURIER":
        return False
    return (
        db.query(OrderPayment.id)
        .filter(
            OrderPayment.order_id == order.id,
            OrderPayment.status == "confirmed",
        )
        .first()
        is not None
    )


def notify_online_couriers_about_order(db: Session, order: Order) -> int:
    """Notify eligible online couriers once when an order becomes available."""
    if not _is_available_to_couriers(db, order):
        return 0

    has_active_order = exists().where(
        Order.courier_id == User.id,
        Order.status.in_(ACTIVE_COURIER_STATUSES),
        Order.hidden_for_courier == False,  # noqa: E712
    )
    couriers = (
        db.query(User)
        .filter(
            User.is_courier == True,  # noqa: E712
            User.is_active == True,  # noqa: E712
            User.is_online == True,  # noqa: E712
            ~has_active_order,
        )
        .all()
    )
    if not couriers:
        return 0

    courier_ids = [courier.id for courier in couriers]
    already_notified = {
        user_id
        for (user_id,) in db.query(Notification.user_id)
        .filter(
            Notification.user_id.in_(courier_ids),
            Notification.order_id == order.id,
            Notification.title == "Жаңы заказ",
        )
        .all()
    }
    recipients = [courier for courier in couriers if courier.id not in already_notified]
    if not recipients:
        return 0

    distance = float(order.distance_km or 0)
    price = float(order.price or 0)
    body = f"{order.from_address} → {order.to_address} · {distance:.1f} км · {price:.0f} сом"
    data = {
        "order_id": str(order.id),
        "type": "new_order",
        "action": "open_available_orders",
    }

    for courier in recipients:
        db.add(
            Notification(
                user_id=courier.id,
                title="Жаңы заказ",
                message=body,
                order_id=order.id,
            )
        )
    db.commit()

    for courier in recipients:
        if not courier.fcm_token:
            continue
        try:
            fcm_service.send_push_to_user(
                courier,
                title="Жаңы заказ",
                body=body,
                data=data,
                channel_id="urgent_orders_v3",
            )
        except Exception:
            logger.exception("Failed to notify courier_id=%s about order_id=%s", courier.id, order.id)

    try:
        from app.services.web_push import notify_user

        for courier in recipients:
            notify_user(
                db,
                user_id=courier.id,
                title="Жаңы заказ",
                body=body,
                data=data,
            )
    except Exception:
        logger.exception("Failed to send courier web push for order_id=%s", order.id)

    return len(recipients)
