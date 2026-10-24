"""End-to-end walk through the enterprise portal, the way the enterprise app uses it.

Every request goes through the real FastAPI app (routing, auth, validation)
against an in-memory SQLite database. Only the outside world is stubbed:
FCM / web push / courier notifications and the R2 image store.
"""
from datetime import timedelta
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api import deps
from app.core.database import Base
from app.core.security import create_access_token, hash_password
from app.main import app
from app.models.enterprise import Enterprise
from app.models.order import Order
from app.models.user import User

ENTERPRISE_PHONE = "+996700100200"
ENTERPRISE_PASSWORD = "secret123"
CUSTOMER_PHONE = "+996700300400"
CUSTOMER_PASSWORD = "custpass1"
CAMPAIGN_DAY = timedelta(hours=24, minutes=1)


@pytest.fixture()
def env(monkeypatch):
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)

    def _get_db():
        db = Session()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[deps.get_db] = _get_db

    # Outside world: record pushes instead of sending them.
    pushes = []
    from app.services import courier_notifications, fcm, media_upload, web_push

    monkeypatch.setattr(fcm, "send_push", lambda *a, **k: pushes.append(("fcm", a, k)) or True)
    monkeypatch.setattr(fcm, "send_push_to_user", lambda *a, **k: pushes.append(("fcm_user", a, k)) or True)
    monkeypatch.setattr(web_push, "notify_enterprise", lambda *a, **k: pushes.append(("web", a, k)))
    monkeypatch.setattr(
        courier_notifications,
        "notify_online_couriers_about_order",
        lambda *a, **k: pushes.append(("couriers", a, k)) or 0,
    )
    uploads = {}
    monkeypatch.setattr(
        media_upload,
        "upload_bytes",
        lambda key, data, ct: uploads.setdefault(key, data) and f"https://media.test/{key}",
    )
    monkeypatch.setattr(media_upload, "delete_object", lambda url: None)

    db = Session()
    owner = User(
        phone=ENTERPRISE_PHONE,
        name="Ашкана ээси",
        hashed_password=hash_password(ENTERPRISE_PASSWORD),
        is_active=True,
        is_enterprise=True,
    )
    customer = User(
        phone=CUSTOMER_PHONE,
        name="Кардар",
        hashed_password=hash_password(CUSTOMER_PASSWORD),
        is_active=True,
    )
    db.add_all([owner, customer])
    db.flush()
    enterprise = Enterprise(
        name="Тест Ашкана",
        category="food",
        phone=ENTERPRISE_PHONE,
        address="Баткен, борбор",
        lat=40.06,
        lon=70.82,
        owner_user_id=owner.id,
        is_active=True,
    )
    db.add(enterprise)
    db.flush()
    owner.enterprise_id = enterprise.id
    db.commit()

    client = TestClient(app)  # no `with`: skip the campaign scheduler startup
    yield {
        "client": client,
        "db": db,
        "Session": Session,
        "owner_id": owner.id,
        "customer_id": customer.id,
        "enterprise_id": enterprise.id,
        "pushes": pushes,
        "uploads": uploads,
    }

    db.close()
    app.dependency_overrides.pop(deps.get_db, None)


def _login(client, phone=ENTERPRISE_PHONE, password=ENTERPRISE_PASSWORD):
    return client.post("/enterprise-portal/login", json={"phone": phone, "password": password})


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _ok(resp, code=200):
    assert resp.status_code == code, f"{resp.request.method} {resp.request.url} -> {resp.status_code}: {resp.text}"
    return resp.json()


def test_full_enterprise_app_flow(env):
    c = env["client"]

    # ── Login (phone typed the way people type it) ──────────────────────────
    login = _ok(_login(c, phone="0700 100 200"))
    assert login["enterprise"]["enterprise_name"] == "Тест Ашкана"
    h = _auth(login["access_token"])

    # ── Profile, push token, location, open/close ───────────────────────────
    me = _ok(c.get("/enterprise-portal/me", headers=h))
    assert me["name"] == "Тест Ашкана" and me["is_active"] is True

    _ok(c.post("/enterprise-portal/fcm-token", headers=h, json={"token": "device-1"}))

    loc = _ok(c.patch("/enterprise-portal/me/location", headers=h, json={"lat": 40.07, "lon": 70.83}))
    assert loc == {"lat": 40.07, "lon": 70.83}

    for value in (True, False, None):
        res = _ok(c.patch("/enterprise-portal/me/open-status", headers=h, json={"is_open": value}))
        assert res["is_open_override"] is value

    # ── Menu: categories ────────────────────────────────────────────────────
    _ok(c.post("/enterprise-portal/categories", headers=h, json={"name": "Тамактар", "sort_order": 1}))
    _ok(c.post("/enterprise-portal/categories", headers=h, json={"name": "Суусундуктар", "sort_order": 2}))
    cats = _ok(c.get("/enterprise-portal/categories", headers=h))
    assert [x["name"] for x in cats] == ["Тамактар", "Суусундуктар"]
    food_id, drinks_id = cats[0]["id"], cats[1]["id"]

    renamed = _ok(c.put(
        f"/enterprise-portal/categories/{drinks_id}",
        headers=h,
        json={"name": "Ичимдиктер", "is_active": True, "sort_order": 2},
    ))
    assert renamed["name"] == "Ичимдиктер"

    empty = c.post("/enterprise-portal/categories", headers=h, json={"name": "  ", "sort_order": 0})
    assert empty.status_code == 400

    # ── Menu: products ──────────────────────────────────────────────────────
    plov = _ok(c.post("/enterprise-portal/products", headers=h, json={
        "name": "Палоо", "price": 250, "category_id": food_id, "stock": 20,
    }))
    assert plov["category_name"] == "Тамактар" and plov["price"] == 250.0
    tea = _ok(c.post("/enterprise-portal/products", headers=h, json={
        "name": "Чай", "price": 50, "category_id": drinks_id, "stock": 5,
    }))
    temp = _ok(c.post("/enterprise-portal/products", headers=h, json={"name": "Убактылуу", "price": 10}))

    negative = c.post("/enterprise-portal/products", headers=h, json={"name": "X", "price": -1})
    assert negative.status_code == 400

    updated = _ok(c.put(f"/enterprise-portal/products/{plov['id']}", headers=h, json={"price": 270}))
    assert updated["price"] == 270.0

    image = _ok(c.post(
        f"/enterprise-portal/products/{plov['id']}/image",
        headers=h,
        files={"file": ("plov.jpg", b"\xff\xd8\xff fake jpeg", "image/jpeg")},
    ))
    assert image["image_url"].startswith("https://media.test/products/")

    bad_image = c.post(
        f"/enterprise-portal/products/{plov['id']}/image",
        headers=h,
        files={"file": ("notes.txt", b"hello", "text/plain")},
    )
    assert bad_image.status_code == 400

    _ok(c.delete(f"/enterprise-portal/products/{temp['id']}", headers=h))
    products = _ok(c.get("/enterprise-portal/products", headers=h))
    assert {p["name"] for p in products} == {"Палоо", "Чай"}

    # ── Payment QR ──────────────────────────────────────────────────────────
    qr = _ok(c.post(
        "/enterprise-portal/payment-qr",
        headers=h,
        files={"file": ("qr.png", b"\x89PNG fake", "image/png")},
    ))
    assert qr["payment_qr_url"].startswith("https://media.test/qr/")
    assert _ok(c.get("/enterprise-portal/me", headers=h))["payment_qr_url"] == qr["payment_qr_url"]

    # ── Local delivery order: PREPARING → WAITING_COURIER (couriers told) ──
    delivery = _ok(c.post("/enterprise-portal/orders/create-local", headers=h, json={
        "order_type": "delivery",
        "customer_phone": "+996700555666",
        "to_address": "Баткен, Ленин көч. 5",
        "to_lat": 40.05,
        "to_lng": 70.81,
        "items": [{"product_id": plov["id"], "quantity": 2}, {"product_id": tea["id"], "quantity": 1}],
        "note": "Ачуу болбосун",
    }))
    assert delivery["status"] == "PREPARING" and delivery["source"] == "local"
    assert delivery["items_total"] == 2 * 270 + 50
    assert delivery["price"] > 0  # delivery fee from distance
    assert "Эскертүү: Ачуу болбосун" in delivery["description"]

    stocks = {p["name"]: p["stock"] for p in _ok(c.get("/enterprise-portal/products", headers=h))}
    assert stocks == {"Палоо": 18, "Чай": 4}

    missing_address = c.post("/enterprise-portal/orders/create-local", headers=h, json={
        "order_type": "delivery", "customer_phone": "+996700555666",
        "items": [{"product_id": plov["id"], "quantity": 1}],
    })
    assert missing_address.status_code == 400

    # The app sends `note=null`, which Dio encodes as a bare `note`.
    _ok(c.post(
        f"/enterprise-portal/orders/{delivery['id']}/update-status?status=WAITING_COURIER&note",
        headers=h,
    ))
    assert any(kind == "couriers" for kind, *_ in env["pushes"])
    assert _ok(c.get(f"/enterprise-portal/orders/{delivery['id']}", headers=h))["status"] == "WAITING_COURIER"

    # Delivery orders only take the statuses an enterprise may set.
    bad_status = c.post(f"/enterprise-portal/orders/{delivery['id']}/update-status?status=DELIVERED", headers=h)
    assert bad_status.status_code == 400

    # ── Dine-in order: PREPARING → READY → COMPLETED ───────────────────────
    dine = _ok(c.post("/enterprise-portal/orders/create-local", headers=h, json={
        "order_type": "dine_in",
        "table_number": "3",
        "items": [{"product_id": tea["id"], "quantity": 2}],
    }))
    assert dine["to_address"] == "Стол №3" and dine["price"] == 0.0

    _ok(c.post(f"/enterprise-portal/orders/{dine['id']}/update-status?status=READY&note", headers=h))
    _ok(c.post(f"/enterprise-portal/orders/{dine['id']}/update-status?status=COMPLETED&note", headers=h))
    done_again = c.post(f"/enterprise-portal/orders/{dine['id']}/update-status?status=CANCELLED", headers=h)
    assert done_again.status_code == 400

    # ── Active list vs history ─────────────────────────────────────────────
    active = _ok(c.get("/enterprise-portal/orders", headers=h))
    assert [o["id"] for o in active] == [delivery["id"]]
    waiting = _ok(c.get("/enterprise-portal/orders", headers=h, params={"status": "WAITING_COURIER"}))
    assert [o["id"] for o in waiting] == [delivery["id"]]
    history = _ok(c.get("/enterprise-portal/history", headers=h))
    assert [o["id"] for o in history] == [dine["id"]]

    # ── Online order paid by QR: customer pays, enterprise confirms/rejects ─
    db = env["db"]
    online_orders = []
    for total in (300, 120):
        o = Order(
            user_id=env["customer_id"],
            enterprise_id=env["enterprise_id"],
            category="food",
            description="Палоо x1",
            from_address="Баткен, борбор",
            to_address="Баткен, Ош көч. 1",
            distance_km=Decimal("1.5"),
            price=Decimal("80"),
            items_total=Decimal(total),
            status="WAITING_COURIER",
            source="online",
            order_type="delivery",
        )
        db.add(o)
        online_orders.append(o)
    db.commit()
    paid_id, rejected_id = (o.id for o in online_orders)

    customer_h = _auth(create_access_token(env["customer_id"]))
    pay1 = _ok(c.post("/enterprise-portal/payments", headers=customer_h, json={
        "order_id": paid_id, "amount": 380, "screenshot_url": "https://media.test/pay1.jpg",
    }))
    pay2 = _ok(c.post("/enterprise-portal/payments", headers=customer_h, json={
        "order_id": rejected_id, "amount": 200, "screenshot_url": "https://media.test/pay2.jpg",
    }))

    # A customer token must not open the enterprise portal.
    assert c.get("/enterprise-portal/payments", headers=customer_h).status_code == 403

    pending = _ok(c.get("/enterprise-portal/payments", headers=h, params={"status": "pending"}))
    assert {p["id"] for p in pending} == {pay1["id"], pay2["id"]}

    confirmed = _ok(c.post(f"/enterprise-portal/payments/{pay1['id']}/confirm", headers=h, json={}))
    assert confirmed["status"] == "confirmed"
    assert _ok(c.get(f"/enterprise-portal/orders/{paid_id}", headers=h))["status"] == "ACCEPTED"

    rejected = _ok(c.post(
        f"/enterprise-portal/payments/{pay2['id']}/reject", headers=h, json={"note": "Сумма туура эмес"},
    ))
    assert rejected["status"] == "rejected" and rejected["note"] == "Сумма туура эмес"

    # ── Stats and reports ──────────────────────────────────────────────────
    stats = _ok(c.get("/enterprise-portal/stats", headers=h))
    assert stats["total_orders"] == 4
    assert stats["completed_orders"] == 1
    assert stats["local_revenue"] == 100.0  # dine-in: 2 × 50
    assert stats["products_count"] == 2 and stats["categories_count"] == 2

    for days in (1, 7, 30):
        report = _ok(c.get("/enterprise-portal/reports", headers=h, params={"days": days}))
        assert report["total_orders"] == 4 and len(report["daily"]) == days
        assert report["dine_in_orders"] == 1 and report["local_orders"] == 1 and report["online_orders"] == 2
    assert c.get("/enterprise-portal/reports", headers=h, params={"days": 3}).status_code == 400

    # ── History cleanup ────────────────────────────────────────────────────
    _ok(c.delete(f"/enterprise-portal/history/{dine['id']}", headers=h))
    assert dine["id"] not in [o["id"] for o in _ok(c.get("/enterprise-portal/history", headers=h))]
    _ok(c.delete("/enterprise-portal/history", headers=h))

    # ── Category delete keeps its products (moved to uncategorized) ────────
    _ok(c.delete(f"/enterprise-portal/categories/{drinks_id}", headers=h))
    tea_now = next(p for p in _ok(c.get("/enterprise-portal/products", headers=h)) if p["name"] == "Чай")
    assert tea_now["category_id"] is None

    # ── QR delete ───────────────────────────────────────────────────────────
    _ok(c.delete("/enterprise-portal/payment-qr", headers=h))
    assert _ok(c.get("/enterprise-portal/me", headers=h))["payment_qr_url"] is None

    # ── Change password, then log in with the new one ───────────────────────
    wrong = c.post("/enterprise-portal/change-password", headers=h, json={
        "current_password": "nope", "new_password": "newpass99",
    })
    assert wrong.status_code == 400
    _ok(c.post("/enterprise-portal/change-password", headers=h, json={
        "current_password": ENTERPRISE_PASSWORD, "new_password": "newpass99",
    }))
    assert _login(c).status_code == 401
    _ok(_login(c, password="newpass99"))


def test_login_refusals_explain_the_reason(env):
    """The app now shows `detail`, so every refusal must carry a clear one."""
    c = env["client"]
    db = env["Session"]()
    owner = db.get(User, env["owner_id"])
    enterprise = db.get(Enterprise, env["enterprise_id"])

    wrong = _login(c, password="wrong")
    assert wrong.status_code == 401
    assert wrong.json()["detail"] == "Телефон же сырсөз туура эмес"

    enterprise.is_active = False
    db.commit()
    inactive = _login(c)
    assert inactive.status_code == 403
    assert inactive.json()["detail"] == "Ишкана активдүү эмес. Администратор менен байланышыңыз."

    enterprise.is_active = True
    owner.enterprise_id = None
    db.commit()
    unlinked = _login(c)
    assert unlinked.status_code == 403
    assert unlinked.json()["detail"] == "Бул аккаунт ишкана колдонуучусу эмес"

    owner.is_active = False
    db.commit()
    blocked = _login(c)
    assert blocked.status_code == 403
    assert blocked.json()["detail"] == "Каттоо эсеби бөгөттөлгөн"

    customer = _login(c, phone=CUSTOMER_PHONE, password=CUSTOMER_PASSWORD)
    assert customer.status_code == 403
    assert customer.json()["detail"] == "Бул аккаунт ишкана колдонуучусу эмес"
    db.close()


def test_login_prefers_enterprise_account_when_number_is_shared(env):
    """A customer account and the enterprise login can share one number.

    The admin panel stores the enterprise phone exactly as typed, so the
    owner's customer account (+996…) and enterprise login (0…) are two rows
    that both match the number. Login used to take whichever row came first
    and refused the correct enterprise password.
    """
    c = env["client"]
    db = env["Session"]()

    # The owner signed up in the customer app first, so that row is older.
    customer = db.get(User, env["customer_id"])
    customer.phone = "+996700900800"
    customer.hashed_password = hash_password("customer-pass")
    # Later the admin created the enterprise login, typing the number as 0….
    db.add(User(
        phone="0700900800",
        name="Ишкана логини",
        hashed_password=hash_password(ENTERPRISE_PASSWORD),
        is_active=True,
        is_enterprise=True,
        enterprise_id=env["enterprise_id"],
    ))
    db.commit()

    # Enterprise password → enterprise account, whichever format is typed.
    for typed in ("+996700900800", "0700900800", "700 900 800"):
        res = _login(c, phone=typed)
        assert res.status_code == 200, (typed, res.text)
        assert res.json()["enterprise"]["enterprise_name"] == "Тест Ашкана"

    # The customer password still reaches the customer row, which is refused.
    customer_only = _login(c, phone="+996700900800", password="customer-pass")
    assert customer_only.status_code == 403
    assert customer_only.json()["detail"] == "Бул аккаунт ишкана колдонуучусу эмес"

    # Same password on both rows: the enterprise account still wins.
    customer.hashed_password = hash_password(ENTERPRISE_PASSWORD)
    db.commit()
    assert _login(c, phone="+996700900800").status_code == 200

    # A row whose hash passlib cannot read must not break the login.
    customer.hashed_password = "legacy-plain-text"
    db.commit()
    assert _login(c, phone="+996700900800").status_code == 200
    db.close()


# ── Promo notifications submitted by an enterprise ──────────────────────────


@pytest.fixture()
def promo(env, monkeypatch):
    """Adds an admin, a menu item and a recorder for campaign pushes."""
    from app.services import fcm

    multicasts = []
    monkeypatch.setattr(
        fcm,
        "send_push_to_tokens",
        lambda tokens, **k: multicasts.append({"tokens": list(tokens), **k}) or len(tokens),
    )
    db = env["Session"]()
    admin = User(
        phone="+996700000001",
        name="Админ",
        hashed_password=hash_password("admin-pass"),
        is_active=True,
        is_admin=True,
    )
    customer = db.get(User, env["customer_id"])
    customer.fcm_token = "customer-device"
    db.add(admin)
    db.commit()
    c = env["client"]
    ent_h = _auth(_ok(_login(c))["access_token"])
    plov = _ok(c.post("/enterprise-portal/products", headers=ent_h, json={"name": "Палоо", "price": 250}))
    env.update(
        ent_h=ent_h,
        admin_h=_auth(create_access_token(admin.id)),
        plov_id=plov["id"],
        multicasts=multicasts,
    )
    db.close()
    return env


def _submit(c, h, **overrides):
    body = {
        "title": "Палоо 20% арзан",
        "message": "Бүгүн гана!",
        "image_url": "https://media.test/notifications/plov.jpg",
    }
    body.update(overrides)
    return c.post("/enterprise-portal/campaigns", headers=h, json=body)


def test_enterprise_promo_waits_for_admin_then_reaches_everyone(promo):
    from app.models.notification import Notification

    c, h, admin_h = promo["client"], promo["ent_h"], promo["admin_h"]

    picture = _ok(c.post(
        "/enterprise-portal/notifications/image",
        headers=h,
        files={"file": ("promo.png", b"\x89PNG fake", "image/png")},
    ))
    assert picture["url"].startswith(f"https://media.test/notifications/enterprise-{promo['enterprise_id']}/")

    submitted = _ok(_submit(c, h, image_url=picture["url"], product_id=promo["plov_id"]))
    assert submitted["status"] == "pending_review"
    assert submitted["product_name"] == "Палоо"

    # Nothing reaches users before review — not even through the scheduler.
    from app.services.campaigns import send_due_campaigns

    db = promo["Session"]()
    assert send_due_campaigns(db) == 0
    assert db.query(Notification).count() == 0
    assert promo["multicasts"] == []

    # The admin sees it with the shop and the menu item.
    listed = next(x for x in _ok(c.get("/admin/campaigns", headers=admin_h)) if x["id"] == submitted["id"])
    assert listed["status"] == "pending_review"
    assert listed["created_by_enterprise_name"] == "Тест Ашкана"
    assert listed["product_name"] == "Палоо"

    approved = _ok(c.post(f"/admin/campaigns/{submitted['id']}/approve", headers=admin_h, json={}))
    assert approved["sent_to"] == 3  # owner, customer, admin: every active user

    rows = db.query(Notification).all()
    assert len(rows) == 3
    assert {r.image_url for r in rows} == {picture["url"]}
    assert {r.enterprise_id for r in rows} == {promo["enterprise_id"]}

    push = promo["multicasts"][0]
    assert push["tokens"] == ["customer-device"]
    assert push["image_url"] == picture["url"]
    assert push["data"] == {
        "type": "promo",
        "enterprise_id": str(promo["enterprise_id"]),
        "enterprise_category": "food",
        "product_id": str(promo["plov_id"]),
    }
    assert any(kind == "web" for kind, *_ in promo["pushes"])  # enterprise told

    mine = _ok(c.get("/enterprise-portal/campaigns", headers=h))
    assert mine["campaigns"][0]["status"] == "sent"
    assert mine["campaigns"][0]["sent_count"] == 3

    # A second approval (double click, second admin) must not send it again.
    again = c.post(f"/admin/campaigns/{submitted['id']}/approve", headers=admin_h, json={})
    assert again.status_code == 400
    assert len(promo["multicasts"]) == 1
    db.close()


def test_enterprise_promo_limit_is_one_per_day(promo):
    from app.models.notification_campaign import NotificationCampaign

    c, h, admin_h = promo["client"], promo["ent_h"], promo["admin_h"]

    first = _ok(_submit(c, h))
    blocked = _submit(c, h)
    assert blocked.status_code == 429
    assert blocked.json()["detail"].startswith("Күнүнө бир гана билдирүү жөнөтсө болот.")
    assert _ok(c.get("/enterprise-portal/campaigns", headers=h))["next_allowed_at"] is not None

    # Withdrawing a draft gives the day back.
    _ok(c.post(f"/enterprise-portal/campaigns/{first['id']}/cancel", headers=h))
    second = _ok(_submit(c, h))

    # So does a rejection, and the enterprise sees why.
    rejected = _ok(c.post(
        f"/admin/campaigns/{second['id']}/reject", headers=admin_h, json={"note": "Сүрөт бүдөмүк"},
    ))
    assert rejected["status"] == "rejected"
    mine = _ok(c.get("/enterprise-portal/campaigns", headers=h))
    assert mine["campaigns"][0]["review_note"] == "Сүрөт бүдөмүк"
    assert mine["next_allowed_at"] is None
    assert c.post(f"/admin/campaigns/{second['id']}/approve", headers=admin_h, json={}).status_code == 400

    third = _ok(_submit(c, h))
    assert _submit(c, h).status_code == 429
    # A reviewed draft can no longer be withdrawn.
    _ok(c.post(f"/admin/campaigns/{third['id']}/approve", headers=admin_h, json={}))
    assert c.post(f"/enterprise-portal/campaigns/{third['id']}/cancel", headers=h).status_code == 400

    # 24 hours later the enterprise may submit again.
    db = promo["Session"]()
    row = db.get(NotificationCampaign, third["id"])
    row.created_at = row.created_at - CAMPAIGN_DAY
    db.commit()
    db.close()
    _ok(_submit(c, h))


def test_enterprise_promo_validation(promo, env):
    c, h = promo["client"], promo["ent_h"]

    assert _submit(c, h, title="  ").status_code == 400
    assert _submit(c, h, message="x" * 501).status_code == 400
    assert _submit(c, h, image_url="http://insecure.test/x.jpg").status_code == 400

    # A product from another shop cannot be advertised.
    db = env["Session"]()
    from app.models.enterprise_product import EnterpriseProduct

    other = Enterprise(name="Башка", category="food", owner_user_id=env["customer_id"], is_active=True)
    db.add(other)
    db.flush()
    foreign = EnterpriseProduct(enterprise_id=other.id, name="Бөтөн", price=1)
    db.add(foreign)
    db.commit()
    assert _submit(c, h, product_id=foreign.id).status_code == 400
    db.close()

    # No picture is fine; none of the failures above used up the day.
    assert _ok(_submit(c, h, image_url=None))["image_url"] is None

    # Customers and enterprises cannot review campaigns.
    customer_h = _auth(create_access_token(env["customer_id"]))
    assert c.post("/admin/campaigns/1/approve", headers=customer_h, json={}).status_code == 403
    assert c.post("/admin/campaigns/1/approve", headers=h, json={}).status_code == 403
