"""Rewarding users who bring a friend to the app."""
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.notification import Notification
from app.models.setting import Setting
from app.models.user import User
from app.services import fcm as fcm_service
from app.services.wallet import topup

logger = logging.getLogger(__name__)

DEFAULT_BONUS = 20.0
DEFAULT_DAILY_LIMIT = 5


def referral_bonus(db: Session) -> float:
    """What a successful invite pays, from settings."""
    return _setting(db, "referral_bonus", DEFAULT_BONUS)


def _setting(db: Session, key: str, fallback: float) -> float:
    row = db.query(Setting).filter(Setting.key == key).first()
    if row is None:
        return fallback
    try:
        return float(row.value)
    except (TypeError, ValueError):
        return fallback


def find_referrer(db: Session, code: str | None) -> User | None:
    """The user whose invite code this is, or None.

    Codes are the unique_id every user already has ("BJ000123"), so there is
    nothing extra to generate or for the user to keep track of.
    """
    normalized = (code or "").strip().upper()
    if not normalized:
        return None
    return (
        db.query(User)
        .filter(
            func.upper(User.unique_id) == normalized,
            User.is_active == True,  # noqa: E712
        )
        .first()
    )


def rewards_paid_today(db: Session, referrer_id: int) -> int:
    """How many invites this user has already been paid for today.

    Registration hands out a welcome bonus of its own, so an unlimited invite
    bonus would pay someone to register fake accounts. The daily cap keeps an
    honest inviter unaffected while making that unprofitable to scale.
    """
    since = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=1)
    return (
        db.query(func.count(User.id))
        .filter(
            User.referred_by_user_id == referrer_id,
            User.created_at >= since,
        )
        .scalar()
        or 0
    )


def apply_referral(db: Session, new_user: User, code: str | None) -> float:
    """Link a new registration to its inviter and pay the bonus.

    Returns the amount paid — 0 when there is no code, the code is unknown,
    it is the user's own, or the inviter is over the daily cap. Never raises:
    a problem with the invite must not cost someone their registration.
    """
    try:
        referrer = find_referrer(db, code)
        if referrer is None or referrer.id == new_user.id:
            return 0.0

        new_user.referred_by_user_id = referrer.id
        db.flush()

        limit = int(_setting(db, "referral_daily_limit", DEFAULT_DAILY_LIMIT))
        if limit > 0 and rewards_paid_today(db, referrer.id) > limit:
            logger.info(
                "Referral cap reached for user %s, no bonus for %s",
                referrer.id,
                new_user.id,
            )
            return 0.0

        bonus = _setting(db, "referral_bonus", DEFAULT_BONUS)
        if bonus <= 0:
            return 0.0

        topup(db, referrer, bonus, kind="REFERRAL_BONUS")
        _notify(db, referrer, new_user, bonus)
        return bonus
    except Exception:
        logger.exception("Referral handling failed for user %s", new_user.id)
        return 0.0


def _notify(db: Session, referrer: User, new_user: User, bonus: float) -> None:
    title = "🎁 Дос кошулду!"
    body = (
        f"{new_user.name} сиздин чакырууңуз менен катталды. "
        f"Балансыңызга {bonus:.0f} сом кошулду."
    )
    db.add(
        Notification(
            user_id=referrer.id,
            title=title,
            message=body,
            notification_type="referral",
            is_read=False,
        )
    )
    try:
        fcm_service.send_push_to_user(
            referrer,
            title=title,
            body=body,
            data={"type": "referral"},
        )
    except Exception:
        logger.warning("Referral push failed for user %s", referrer.id)
