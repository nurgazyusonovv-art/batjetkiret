"""Campaign broadcasts carry a picture and reach every device in one multicast."""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api import admin as admin_api
from app.core.database import Base
from app.models.notification import Notification
from app.models.user import User

IMAGE = "https://cdn.example.r2.dev/notifications/abc.jpg"


def _session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def _user(phone: str, token: str | None):
    return User(
        phone=phone,
        name="Customer",
        hashed_password="test",
        is_active=True,
        balance=0,
        fcm_token=token,
    )


def test_broadcast_stores_image_and_sends_one_multicast(monkeypatch):
    db = _session()
    db.add_all([
        _user("+996700000101", "token-a"),
        _user("+996700000102", "token-b"),
        _user("+996700000103", None),  # no device
    ])
    db.commit()

    calls = []

    def fake_multicast(tokens, **kwargs):
        calls.append((tokens, kwargs))
        return len(tokens)

    monkeypatch.setattr(admin_api.fcm_service, "send_push_to_tokens", fake_multicast)

    payload = admin_api.NotificationCreate(
        title="Арзандатуу!",
        message="Бүгүн 20% жеңилдик",
        image_url=IMAGE,
        type="promo",
    )
    result = admin_api.broadcast_notification(payload, db, admin=None)

    assert result["sent_to"] == 3
    assert result["pushed"] == 2

    # One multicast call, only for devices that actually have a token.
    assert len(calls) == 1
    tokens, kwargs = calls[0]
    assert sorted(tokens) == ["token-a", "token-b"]
    assert kwargs["image_url"] == IMAGE

    stored = db.query(Notification).all()
    assert len(stored) == 3
    assert all(n.image_url == IMAGE for n in stored)
    assert all(n.notification_type == "promo" for n in stored)


def test_broadcast_rejects_unknown_enterprise(monkeypatch):
    db = _session()
    db.add(_user("+996700000104", "token-c"))
    db.commit()
    monkeypatch.setattr(
        admin_api.fcm_service, "send_push_to_tokens", lambda *a, **k: 0
    )

    payload = admin_api.NotificationCreate(
        title="Тест",
        message="Тест",
        enterprise_id=999,
    )
    with pytest.raises(admin_api.HTTPException) as exc:
        admin_api.broadcast_notification(payload, db, admin=None)
    assert exc.value.status_code == 404


def test_user_feed_exposes_picture_and_shop_category():
    from app.api import notifications as notifications_api
    from app.models.enterprise import Enterprise

    db = _session()
    user = _user("+996700000105", None)
    db.add(user)
    shop = Enterprise(
        name="ALI KFC",
        category="food",
        owner_user_id=1,
        is_active=True,
    )
    db.add(shop)
    db.commit()
    db.refresh(user)
    db.refresh(shop)

    db.add(
        Notification(
            user_id=user.id,
            title="Арзандатуу",
            message="Бүгүн 20%",
            image_url=IMAGE,
            enterprise_id=shop.id,
            notification_type="promo",
        )
    )
    db.commit()

    feed = notifications_api.my_notifications(
        limit=50, offset=0, db=db, current_user=user
    )

    assert len(feed) == 1
    item = feed[0]
    assert item["image_url"] == IMAGE
    assert item["enterprise_id"] == shop.id
    # The app needs the category to open the right shop page.
    assert item["enterprise_category"] == "food"
    assert item["type"] == "promo"
