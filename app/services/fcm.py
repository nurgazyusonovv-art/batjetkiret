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

USER_NOTIFICATION_CHANNELS = {
    "messages": ("batken_messages_v3", "message_tone"),
    "order_status": ("order_status_v3", "order_tone"),
    "topup": ("topup_status_v3", "topup_tone"),
    "support": ("support_chat_v3", "support_tone"),
    "urgent": ("urgent_orders_v3", "urgent_tone"),
}

LEGACY_CHANNEL_ALIASES = {
    "batken_messages": "batken_messages_v3",
    "batken_messages_v2": "batken_messages_v3",
    "order_status": "order_status_v3",
    "order_status_v2": "order_status_v3",
    "topup_requests": "topup_status_v3",
    "topup_status": "topup_status_v3",
    "topup_status_v2": "topup_status_v3",
    "support_chat": "support_chat_v3",
    "support_chat_v2": "support_chat_v3",
    "urgent_orders": "urgent_orders_v3",
    "urgent_orders_v2": "urgent_orders_v3",
}

CHANNEL_SOUNDS = {
    channel_id: sound
    for channel_id, sound in USER_NOTIFICATION_CHANNELS.values()
}


def _channel_for_type(notification_type: str | None) -> str:
    normalized = (notification_type or "").lower()
    if normalized in {"order_status", "delivery_status"}:
        return USER_NOTIFICATION_CHANNELS["order_status"][0]
    if normalized in {"topup", "topup_approved", "topup_rejected"}:
        return USER_NOTIFICATION_CHANNELS["topup"][0]
    if normalized in {"support", "support_chat", "support_message"}:
        return USER_NOTIFICATION_CHANNELS["support"][0]
    if normalized in {"new_order", "cancel_request", "cancel_requests"}:
        return USER_NOTIFICATION_CHANNELS["urgent"][0]
    return USER_NOTIFICATION_CHANNELS["messages"][0]


def _resolve_channel(channel_id: str | None, data: dict | None) -> str:
    if channel_id:
        return LEGACY_CHANNEL_ALIASES.get(channel_id, channel_id)
    return _channel_for_type((data or {}).get("type"))


def _sound_for_channel(channel_id: str) -> str:
    return CHANNEL_SOUNDS.get(channel_id, "default")


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


def send_push(
    token: str,
    title: str,
    body: str,
    data: dict | None = None,
    channel_id: str | None = None,
    include_notification: bool = False,
) -> bool:
    """Send a push notification to a single FCM token. Returns True on success.

    include_notification=True  — notification payload кошот (user app үчүн).
    include_notification=False — data-only (admin app, дубль болбосун).
    """
    _init()
    if _messaging is None or not token:
        return False

    try:
        resolved_channel_id = _resolve_channel(channel_id, data)
        sound = _sound_for_channel(resolved_channel_id)
        all_data = {k: str(v) for k, v in (data or {}).items()}
        all_data.update(
            {
                "title": title,
                "body": body,
                "channel_id": resolved_channel_id,
                "sound": sound,
            }
        )
        message = _messaging.Message(
            notification=_messaging.Notification(title=title, body=body)
            if include_notification
            else None,
            data=all_data,
            token=token,
            android=_messaging.AndroidConfig(
                priority="high",
                notification=_messaging.AndroidNotification(
                    sound=sound,
                    channel_id=resolved_channel_id,
                )
                if include_notification
                else None,
            ),
            apns=_messaging.APNSConfig(
                payload=_messaging.APNSPayload(
                    aps=_messaging.Aps(sound=sound),
                ),
            )
            if include_notification
            else None,
        )
        _messaging.send(message)
        return True
    except Exception as exc:
        logger.warning("FCM send failed (token=%s...): %s", token[:10], exc)
        return False


def send_push_to_user(
    user,
    title: str,
    body: str,
    data: dict | None = None,
    channel_id: str | None = None,
) -> bool:
    """Send push if the user has an FCM token."""
    if user is None or not getattr(user, "fcm_token", None):
        return False
    return send_push(
        user.fcm_token,
        title,
        body,
        data,
        channel_id=channel_id,
        include_notification=True,
    )


def is_initialized() -> bool:
    """Return True if Firebase Admin SDK is ready to send pushes."""
    _init()
    return _messaging is not None
