import json
import logging
from pywebpush import webpush, WebPushException
from app.core.config import settings

logger = logging.getLogger(__name__)


def send_web_push(subscription_json: str, title: str, body: str, data: dict | None = None) -> bool:
    """Send a Web Push notification to a single subscription. Returns True on success."""
    try:
        subscription = json.loads(subscription_json)
        payload = json.dumps({"title": title, "body": body, **(data or {})})
        webpush(
            subscription_info=subscription,
            data=payload,
            vapid_private_key=settings.VAPID_PRIVATE_KEY,
            vapid_claims={"sub": settings.VAPID_EMAIL},
        )
        return True
    except WebPushException as e:
        # 410 Gone = subscription expired/revoked — caller should delete it
        if e.response is not None and e.response.status_code == 410:
            raise
        logger.warning(f"Web push failed: {e}")
        return False
    except Exception as e:
        logger.warning(f"Web push error: {e}")
        return False


def notify_user(db, user_id: int, title: str, body: str, data: dict | None = None):
    """Send push to all active web push subscriptions for a user (Flutter web)."""
    from app.models.user_push_subscription import UserPushSubscription

    subs = db.query(UserPushSubscription).filter(
        UserPushSubscription.user_id == user_id
    ).all()

    stale_ids = []
    for sub in subs:
        try:
            send_web_push(sub.subscription_json, title, body, data)
        except Exception:
            stale_ids.append(sub.id)

    if stale_ids:
        db.query(UserPushSubscription).filter(UserPushSubscription.id.in_(stale_ids)).delete(
            synchronize_session=False
        )
        db.commit()


def notify_enterprise(db, enterprise_id: int, title: str, body: str, data: dict | None = None):
    """Send push to all active web push subscriptions for an enterprise."""
    from app.models.push_subscription import PushSubscription

    subs = db.query(PushSubscription).filter(
        PushSubscription.enterprise_id == enterprise_id
    ).all()

    stale_ids = []
    for sub in subs:
        try:
            send_web_push(sub.subscription_json, title, body, data)
        except Exception:
            # 410 Gone — mark for removal
            stale_ids.append(sub.id)

    if stale_ids:
        db.query(PushSubscription).filter(PushSubscription.id.in_(stale_ids)).delete(
            synchronize_session=False
        )
        db.commit()
