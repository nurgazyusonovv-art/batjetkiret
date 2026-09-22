import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import exists
from sqlalchemy.orm import Session

from app.models.notification import Notification
from app.models.order import Order
from app.models.order_payment import OrderPayment
from app.models.user import User
from app.services import fcm as fcm_service
from app.services.pricing import haversine_km


logger = logging.getLogger(__name__)

# A taxi ride is offered to drivers around the passenger first. Radius is
# generous for a town the size of Batken, and a location older than this says
# nothing about where the driver is now.
NEARBY_RADIUS_KM = 7.0
LOCATION_FRESHNESS = timedelta(minutes=20)

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

    couriers = _prefer_nearby(couriers, order)

    title = (
        "Системадан тышкары заказ"
        if order.source == "admin_external"
        else "Жаңы заказ"
    )
    courier_ids = [courier.id for courier in couriers]
    already_notified = {
        user_id
        for (user_id,) in db.query(Notification.user_id)
        .filter(
            Notification.user_id.in_(courier_ids),
            Notification.order_id == order.id,
            Notification.title == title,
        )
        .all()
    }
    recipients = [courier for courier in couriers if courier.id not in already_notified]
    if not recipients:
        return 0

    if order.source == "admin_external":
        body = f"{order.from_address} → {order.to_address} · Баасы жолдон эсептелет"
    else:
        distance = float(order.distance_km or 0)
        price = float(order.price or 0)
        body = f"{order.from_address} → {order.to_address} · {distance:.1f} км · {price:.0f} сом"
    data = {
        "order_id": str(order.id),
        "type": "new_order",
        "action": "open_available_orders",
        "source": order.source or "online",
    }

    for courier in recipients:
        db.add(
            Notification(
                user_id=courier.id,
                title=title,
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
                title=title,
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
                title=title,
                body=body,
                data=data,
            )
    except Exception:
        logger.exception("Failed to send courier web push for order_id=%s", order.id)

    return len(recipients)


def _prefer_nearby(couriers: list[User], order: Order) -> list[User]:
    """Narrow the list to drivers around the pickup point, nearest first.

    Falls back to everyone when the order has no pickup coordinates or nobody
    nearby has reported a fresh location — an order nobody is told about is
    worse than one offered a little too widely.
    """
    if order.from_latitude is None or order.from_longitude is None:
        return couriers

    cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - LOCATION_FRESHNESS
    nearby: list[tuple[float, User]] = []
    for courier in couriers:
        if courier.current_latitude is None or courier.current_longitude is None:
            continue
        updated = courier.location_updated_at
        if updated is None or updated < cutoff:
            continue
        distance = haversine_km(
            float(order.from_latitude),
            float(order.from_longitude),
            float(courier.current_latitude),
            float(courier.current_longitude),
        )
        if distance <= NEARBY_RADIUS_KM:
            nearby.append((distance, courier))

    if not nearby:
        logger.info(
            "Order %s: no driver with a fresh location nearby, offering to all %d online",
            order.id,
            len(couriers),
        )
        return couriers

    nearby.sort(key=lambda pair: pair[0])
    return [courier for _distance, courier in nearby]
