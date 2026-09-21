"""Scheduled campaigns: send on time, never twice, cancellable before sending."""

from datetime import timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api import admin as admin_api
from app.core.database import Base
from app.models.notification import Notification
from app.models.notification_campaign import NotificationCampaign
from app.models.user import User
from app.services import campaigns as campaigns_service
from app.services.campaigns import claim_campaign, send_due_campaigns, utcnow


def _session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def _user(phone: str, token: str | None = "token"):
    return User(
        phone=phone,
        name="Customer",
        hashed_password="test",
        is_active=True,
        balance=0,
        fcm_token=token,
    )


@pytest.fixture
def no_push(monkeypatch):
    sent = []
    monkeypatch.setattr(
        campaigns_service.fcm_service,
        "send_push_to_tokens",
        lambda tokens, **kwargs: sent.append(tokens) or len(tokens),
    )
    return sent


def _campaign(db, **overrides):
    values = {
        "title": "Арзандатуу",
        "message": "Бүгүн 20%",
        "status": NotificationCampaign.STATUS_SCHEDULED,
    }
    values.update(overrides)
    campaign = NotificationCampaign(**values)
    db.add(campaign)
    db.commit()
    db.refresh(campaign)
    return campaign


def test_due_campaign_is_sent_and_a_future_one_is_left_alone(no_push):
    db = _session()
    db.add_all([_user("+996700000201"), _user("+996700000202")])
    db.commit()

    due = _campaign(db, scheduled_at=utcnow() - timedelta(minutes=1))
    future = _campaign(db, scheduled_at=utcnow() + timedelta(hours=2))

    assert send_due_campaigns(db) == 1

    db.refresh(due)
    db.refresh(future)
    assert due.status == NotificationCampaign.STATUS_SENT
    assert due.sent_count == 2
    assert due.pushed_count == 2
    assert due.sent_at is not None
    assert future.status == NotificationCampaign.STATUS_SCHEDULED

    # Only the due campaign produced notifications.
    assert db.query(Notification).count() == 2


def test_overdue_campaign_is_still_sent_after_downtime(no_push):
    db = _session()
    db.add(_user("+996700000203"))
    db.commit()
    campaign = _campaign(db, scheduled_at=utcnow() - timedelta(days=1))

    assert send_due_campaigns(db) == 1
    db.refresh(campaign)
    assert campaign.status == NotificationCampaign.STATUS_SENT


def test_a_campaign_can_only_be_claimed_once(no_push):
    db = _session()
    campaign = _campaign(db, scheduled_at=utcnow() - timedelta(minutes=1))

    assert claim_campaign(db, campaign.id) is True
    # A second worker racing for the same row loses.
    assert claim_campaign(db, campaign.id) is False


def test_sending_twice_produces_no_duplicate_notifications(no_push):
    db = _session()
    db.add(_user("+996700000204"))
    db.commit()
    _campaign(db, scheduled_at=utcnow() - timedelta(minutes=1))

    send_due_campaigns(db)
    send_due_campaigns(db)

    assert db.query(Notification).count() == 1


def test_cancelled_campaign_never_sends(no_push):
    db = _session()
    db.add(_user("+996700000205"))
    db.commit()
    campaign = _campaign(db, scheduled_at=utcnow() - timedelta(minutes=1))

    admin_api.cancel_campaign(campaign.id, db, admin=None)
    db.refresh(campaign)
    assert campaign.status == NotificationCampaign.STATUS_CANCELLED

    assert send_due_campaigns(db) == 0
    assert db.query(Notification).count() == 0


def test_a_sent_campaign_cannot_be_cancelled(no_push):
    db = _session()
    db.add(_user("+996700000206"))
    db.commit()
    campaign = _campaign(db, scheduled_at=utcnow() - timedelta(minutes=1))
    send_due_campaigns(db)

    with pytest.raises(admin_api.HTTPException) as exc:
        admin_api.cancel_campaign(campaign.id, db, admin=None)
    assert exc.value.status_code == 400


def test_broadcast_with_a_future_time_schedules_instead_of_sending(no_push):
    db = _session()
    db.add(_user("+996700000207"))
    db.commit()

    payload = admin_api.NotificationCreate(
        title="Эртеңки акция",
        message="Эртең башталат",
        scheduled_at=utcnow() + timedelta(hours=5),
    )
    result = admin_api.broadcast_notification(payload, db, admin=None)

    assert "campaign_id" in result
    assert db.query(Notification).count() == 0
    campaign = db.query(NotificationCampaign).one()
    assert campaign.status == NotificationCampaign.STATUS_SCHEDULED


def test_broadcast_without_a_time_sends_right_away(no_push):
    db = _session()
    db.add(_user("+996700000208"))
    db.commit()

    payload = admin_api.NotificationCreate(title="Азыр", message="Дароо")
    result = admin_api.broadcast_notification(payload, db, admin=None)

    assert result["sent_to"] == 1
    assert db.query(Notification).count() == 1
    campaign = db.query(NotificationCampaign).one()
    assert campaign.status == NotificationCampaign.STATUS_SENT


def test_scheduled_at_from_the_admin_panel_is_stored_as_naive_utc(no_push):
    """The panel sends an ISO string with Z, which pydantic makes tz-aware."""
    db = _session()
    db.add(_user("+996700000209"))
    db.commit()

    # Simulates the exact payload the browser posts.
    payload = admin_api.NotificationCreate(
        title="Эртең",
        message="Акция",
        scheduled_at="2099-01-01T10:00:00Z",
    )
    result = admin_api.broadcast_notification(payload, db, admin=None)

    assert "campaign_id" in result
    campaign = db.query(NotificationCampaign).one()
    assert campaign.status == NotificationCampaign.STATUS_SCHEDULED
    # Stored naive, so comparing against utcnow() in the scheduler works.
    assert campaign.scheduled_at.tzinfo is None
    assert campaign.scheduled_at.hour == 10
    assert db.query(Notification).count() == 0


def test_an_aware_past_time_sends_immediately(no_push):
    db = _session()
    db.add(_user("+996700000210"))
    db.commit()

    payload = admin_api.NotificationCreate(
        title="Кечиккен",
        message="Дароо кетсин",
        scheduled_at="2020-01-01T10:00:00Z",
    )
    result = admin_api.broadcast_notification(payload, db, admin=None)

    assert result["sent_to"] == 1
    assert db.query(Notification).count() == 1
