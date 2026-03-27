"""Firebase Cloud Messaging service.

Supports two ways to provide credentials:
1. FIREBASE_SERVICE_ACCOUNT_JSON env var — full JSON string (for Railway/cloud)
2. FIREBASE_SERVICE_ACCOUNT_PATH env var — path to JSON file (default: firebase-service-account.json)
"""
import json
import logging
import os

logger = logging.getLogger("app.fcm")

_initialized = False
_messaging = None


def _init():
    global _initialized, _messaging
    if _initialized:
        return
    _initialized = True

    try:
        import firebase_admin
        from firebase_admin import credentials, messaging as fb_messaging

        if firebase_admin._apps:
            _messaging = fb_messaging
            return

        # Option 1: full JSON from env var (Railway)
        json_str = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
        if json_str:
            cred = credentials.Certificate(json.loads(json_str))
            firebase_admin.initialize_app(cred)
            _messaging = fb_messaging
            logger.info("Firebase Admin SDK initialized from FIREBASE_SERVICE_ACCOUNT_JSON")
            return

        # Option 2: path to JSON file (local dev)
        key_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "firebase-service-account.json")
        if os.path.exists(key_path):
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
            _messaging = fb_messaging
            logger.info("Firebase Admin SDK initialized from %s", key_path)
            return

        logger.warning(
            "FCM disabled: set FIREBASE_SERVICE_ACCOUNT_JSON or FIREBASE_SERVICE_ACCOUNT_PATH"
        )
    except Exception as exc:
        logger.error("Failed to initialize Firebase Admin SDK: %s", exc)


def send_push(token: str, title: str, body: str, data: dict | None = None) -> bool:
    """Send a push notification to a single FCM token. Returns True on success."""
    _init()
    if _messaging is None or not token:
        return False

    try:
        message = _messaging.Message(
            notification=_messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
            android=_messaging.AndroidConfig(
                priority="high",
                notification=_messaging.AndroidNotification(
                    sound="default",
                    channel_id="batken_messages",
                ),
            ),
            apns=_messaging.APNSConfig(
                payload=_messaging.APNSPayload(
                    aps=_messaging.Aps(sound="default"),
                ),
            ),
        )
        _messaging.send(message)
        return True
    except Exception as exc:
        logger.warning("FCM send failed (token=%s...): %s", token[:10], exc)
        return False


def send_push_to_user(user, title: str, body: str, data: dict | None = None) -> bool:
    """Send push if the user has an FCM token."""
    if user is None or not getattr(user, "fcm_token", None):
        return False
    return send_push(user.fcm_token, title, body, data)


def is_initialized() -> bool:
    """Return True if Firebase Admin SDK is ready to send pushes."""
    _init()
    return _messaging is not None
