"""Inviting a friend pays the inviter — once, and not without limit."""

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.setting import Setting
from app.models.transaction import Transaction
from app.models.user import User
from app.services import referrals as referrals_service
from app.services.referrals import DEFAULT_BONUS, apply_referral


@pytest.fixture(autouse=True)
def no_push(monkeypatch):
    monkeypatch.setattr(
        referrals_service.fcm_service,
        "send_push_to_user",
        lambda *a, **k: True,
    )


def _session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def _user(db, phone: str, code: str | None = None, balance: float = 0):
    user = User(
        phone=phone,
        name=f"User {phone[-3:]}",
        hashed_password="x",
        is_active=True,
        balance=balance,
        unique_id=code,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def test_inviter_is_paid_and_the_link_is_recorded():
    db = _session()
    inviter = _user(db, "+996700000401", code="BJ000001", balance=100)
    joiner = _user(db, "+996700000402")

    paid = apply_referral(db, joiner, "BJ000001")
    db.commit()

    assert paid == DEFAULT_BONUS
    db.refresh(inviter)
    assert float(inviter.balance) == 120.0
    assert joiner.referred_by_user_id == inviter.id

    # The credit is labelled so it is not mistaken for a payment top-up.
    tx = db.query(Transaction).filter(Transaction.user_id == inviter.id).one()
    assert tx.type == "REFERRAL_BONUS"
    assert float(tx.amount) == DEFAULT_BONUS


def test_the_code_is_matched_regardless_of_case_and_spacing():
    db = _session()
    inviter = _user(db, "+996700000403", code="BJ000002")
    joiner = _user(db, "+996700000404")

    assert apply_referral(db, joiner, "  bj000002 ") == DEFAULT_BONUS
    db.commit()
    db.refresh(inviter)
    assert float(inviter.balance) == DEFAULT_BONUS


def test_an_unknown_or_missing_code_pays_nothing():
    db = _session()
    joiner = _user(db, "+996700000405")

    assert apply_referral(db, joiner, None) == 0.0
    assert apply_referral(db, joiner, "") == 0.0
    assert apply_referral(db, joiner, "BJ999999") == 0.0
    assert joiner.referred_by_user_id is None


def test_a_deactivated_inviter_is_not_paid():
    db = _session()
    inviter = _user(db, "+996700000406", code="BJ000003")
    inviter.is_active = False
    db.commit()
    joiner = _user(db, "+996700000407")

    assert apply_referral(db, joiner, "BJ000003") == 0.0


def test_your_own_code_pays_nothing():
    db = _session()
    user = _user(db, "+996700000408", code="BJ000004")

    assert apply_referral(db, user, "BJ000004") == 0.0
    assert user.referred_by_user_id is None


def test_the_daily_cap_stops_paying_for_mass_signups():
    db = _session()
    db.add(Setting(key="referral_daily_limit", value="2"))
    db.commit()
    inviter = _user(db, "+996700000409", code="BJ000005")

    paid = []
    for i in range(4):
        joiner = _user(db, f"+99670000041{i}")
        paid.append(apply_referral(db, joiner, "BJ000005"))
        db.commit()

    # Paid for the first invites, then capped — while every link is still
    # recorded, so the inviter's reach stays visible.
    assert paid[0] == DEFAULT_BONUS
    assert paid[-1] == 0.0
    assert sum(1 for p in paid if p > 0) <= 3
    linked = (
        db.query(User).filter(User.referred_by_user_id == inviter.id).count()
    )
    assert linked == 4


def test_an_old_invite_does_not_count_towards_today_s_cap():
    db = _session()
    db.add(Setting(key="referral_daily_limit", value="1"))
    db.commit()
    inviter = _user(db, "+996700000420", code="BJ000006")

    old = _user(db, "+996700000421")
    old.referred_by_user_id = inviter.id
    old.created_at = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=3)
    db.commit()

    joiner = _user(db, "+996700000422")
    assert apply_referral(db, joiner, "BJ000006") == DEFAULT_BONUS


def test_a_zero_bonus_setting_turns_the_programme_off():
    db = _session()
    db.add(Setting(key="referral_bonus", value="0"))
    db.commit()
    _user(db, "+996700000430", code="BJ000007")
    joiner = _user(db, "+996700000431")

    assert apply_referral(db, joiner, "BJ000007") == 0.0
    # The link is still recorded even when nothing is paid.
    assert joiner.referred_by_user_id is not None
