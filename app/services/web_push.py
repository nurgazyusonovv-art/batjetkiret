import json
import logging
from pywebpush import webpush, WebPushException
from app.core.config import settings

logger = logging.getLogger(__name__)

# Default TTL: 24 hours. Messages expire server-side if device is offline.
_TTL = 86_400


def send_web_push(
    subscription_json: str,
    title: str,
    body: str,
    data: dict | None = None,
) -> bool:
    """Send a Web Push notification to one subscription.

    Payload shape: {"title": str, "body": str, "data": {...}}
    Returns True on success. Raises WebPushException(410) for expired subscriptions
    so callers can clean them up.
    """
    try:
        subscription = json.loads(subscription_json)
        payload = json.dumps({"title": title, "body": body, "data": data or {}})
        webpush(
            subscription_info=subscription,
            data=payload,
            vapid_private_key=settings.VAPID_PRIVATE_KEY,
            vapid_claims={"sub": settings.VAPID_EMAIL},
            ttl=_TTL,
        )
        return True
    except WebPushException as exc:
        if exc.response is not None and exc.response.status_code in (404, 410):
            # Subscription expired or gone — bubble up so caller deletes it
            raise
        logger.warning("Web push failed (non-fatal): %s", exc)
        return False
    except Exception as exc:
        logger.warning("Web push error: %s", exc)
        return False


def _bulk_notify(db, model, filter_clause, title: str, body: str, data: dict | None):
    """Internal helper — send push to all subscriptions matching filter_clause,
    delete stale ones (404/410) in a single batch commit."""
    subs = db.query(model).filter(filter_clause).all()
    if not subs:
        return

    stale_ids: list[int] = []
    for sub in subs:
        try:
            send_web_push(sub.subscription_json, title, body, data)
        except WebPushException:
            # 404/410 — subscription is dead
            stale_ids.append(sub.id)
        except Exception:
            pass  # transient error — keep subscription, retry next time

    if stale_ids:
        db.query(model).filter(model.id.in_(stale_ids)).delete(
            synchronize_session=False
        )
        db.commit()


def notify_user(
    db,
    user_id: int,
    title: str,
    body: str,
    data: dict | None = None,
) -> None:
    """Send push to every active web-push subscription for a customer (Flutter web)."""
    from app.models.user_push_subscription import UserPushSubscription  # avoid circular

    _bulk_notify(
        db,
        UserPushSubscription,
        UserPushSubscription.user_id == user_id,
        title,
        body,
        data,
    )


def notify_enterprise(
    db,
    enterprise_id: int,
    title: str,
    body: str,
    data: dict | None = None,
) -> None:
    """Send push to every active web-push subscription for an enterprise panel browser."""
    from app.models.push_subscription import PushSubscription  # avoid circular

    _bulk_notify(
        db,
        PushSubscription,
        PushSubscription.enterprise_id == enterprise_id,
        title,
        body,
        data,
    )
