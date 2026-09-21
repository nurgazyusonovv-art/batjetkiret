"""Sending notification campaigns, immediately or on a schedule."""
import logging
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.enterprise import Enterprise
from app.models.notification import Notification
from app.models.notification_campaign import NotificationCampaign
from app.models.user import User
from app.services import fcm as fcm_service

logger = logging.getLogger(__name__)


def utcnow() -> datetime:
    """Naive UTC, matching how the rest of the schema stores timestamps."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def to_naive_utc(value: datetime | None) -> datetime | None:
    """Normalise an incoming timestamp to the naive UTC the schema stores.

    The admin panel sends an ISO string ending in Z, which pydantic parses into
    an aware datetime; comparing that against utcnow() raises, and storing it
    in a naive column is ambiguous.
    """
    if value is None or value.tzinfo is None:
        return value
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def deliver_campaign(db: Session, campaign: NotificationCampaign) -> dict:
    """Write a notification for every active user and push it to their devices.

    The caller is responsible for having claimed the campaign first, so this
    never runs twice for the same row.
    """
    users = db.query(User).filter(User.is_active == True).all()  # noqa: E712

    db.bulk_save_objects(
        [
            Notification(
                user_id=u.id,
                title=campaign.title,
                message=campaign.message,
                image_url=campaign.image_url,
                enterprise_id=campaign.enterprise_id,
                notification_type=campaign.notification_type or "promo",
                is_read=False,
            )
            for u in users
        ]
    )

    data = {"type": campaign.notification_type or "promo"}
    if campaign.enterprise_id:
        enterprise = db.query(Enterprise).filter(
            Enterprise.id == campaign.enterprise_id
        ).first()
        if enterprise is not None:
            # The app needs the category to open the shop's page from the push.
            data["enterprise_id"] = str(enterprise.id)
            data["enterprise_category"] = enterprise.category or ""

    # One multicast per 500 devices — a request per user takes minutes.
    delivered = fcm_service.send_push_to_tokens(
        [u.fcm_token for u in users if u.fcm_token],
        title=campaign.title,
        body=campaign.message,
        data=data,
        image_url=campaign.image_url,
    )

    campaign.status = NotificationCampaign.STATUS_SENT
    campaign.sent_at = utcnow()
    campaign.sent_count = len(users)
    campaign.pushed_count = delivered
    db.commit()

    return {"sent_to": len(users), "pushed": delivered}


def claim_campaign(db: Session, campaign_id: int) -> bool:
    """Move a scheduled campaign to 'sending'; False if someone else got it.

    The status check lives in the UPDATE itself, so two workers racing for the
    same campaign cannot both win and send it twice.
    """
    claimed = (
        db.query(NotificationCampaign)
        .filter(
            NotificationCampaign.id == campaign_id,
            NotificationCampaign.status == NotificationCampaign.STATUS_SCHEDULED,
        )
        .update(
            {"status": NotificationCampaign.STATUS_SENDING},
            synchronize_session=False,
        )
    )
    db.commit()
    return claimed == 1


def send_due_campaigns(db: Session) -> int:
    """Send every campaign whose time has come. Returns how many were sent.

    Campaigns whose time passed while the service was down are picked up on the
    next tick, so a restart delays a campaign rather than dropping it.
    """
    now = utcnow()
    due = (
        db.query(NotificationCampaign)
        .filter(
            NotificationCampaign.status == NotificationCampaign.STATUS_SCHEDULED,
            NotificationCampaign.scheduled_at != None,  # noqa: E711
            NotificationCampaign.scheduled_at <= now,
        )
        .order_by(NotificationCampaign.scheduled_at)
        .limit(20)
        .all()
    )

    sent = 0
    for campaign in due:
        if not claim_campaign(db, campaign.id):
            continue  # another worker is already sending it
        try:
            db.refresh(campaign)
            result = deliver_campaign(db, campaign)
            sent += 1
            logger.info(
                "Campaign %s sent to %s users (%s pushes)",
                campaign.id,
                result["sent_to"],
                result["pushed"],
            )
        except Exception as exc:
            db.rollback()
            campaign.status = NotificationCampaign.STATUS_FAILED
            campaign.error = str(exc)[:500]
            db.commit()
            logger.exception("Campaign %s failed", campaign.id)

    return sent
