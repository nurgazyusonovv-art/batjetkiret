from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api import admin as admin_api
from app.api import courier_orders as courier_orders_api
from app.core.database import Base
from app.models.order import Order
from app.models.transaction import Transaction
from app.models.user import User
from app.services.wallet import hold_amount


def _session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def _user(phone: str, name: str, *, is_admin=False, is_courier=False):
    return User(
        phone=phone,
        name=name,
        hashed_password="test",
        is_admin=is_admin,
        is_courier=is_courier,
        is_active=True,
        balance=100,
    )


def test_admin_creates_external_order_from_phone(monkeypatch):
    db = _session()
    admin = _user("+996700000001", "Admin", is_admin=True)
    db.add(admin)
    db.commit()
    db.refresh(admin)
    monkeypatch.setattr(
        admin_api,
        "notify_online_couriers_about_order",
        lambda *_args, **_kwargs: 0,
    )

    result = admin_api.admin_create_order(
        admin_api.AdminCreateOrderRequest(
            phone="0700 123 456",
            category="delivery",
            description="Документ",
            from_address="Баткен, базар",
            to_address="Баткен, борбор",
        ),
        db=db,
        admin=admin,
    )

    order = db.query(Order).filter(Order.id == result["id"]).one()
    assert order.source == "admin_external"
    assert order.customer_phone == "+996700123456"
    assert order.distance_km == 0
    assert order.price == 0
    assert order.user_id == admin.id


def test_courier_completion_charges_rounded_two_percent(monkeypatch):
    db = _session()
    admin = _user("+996700000002", "Admin", is_admin=True)
    courier = _user("+996700000003", "Courier", is_courier=True)
    db.add_all([admin, courier])
    db.commit()
    db.refresh(admin)
    db.refresh(courier)

    order = Order(
        user_id=admin.id,
        courier_id=courier.id,
        category="delivery",
        description="Документ",
        from_address="А",
        to_address="Б",
        distance_km=0,
        price=0,
        source="admin_external",
        order_type="delivery",
        customer_phone="+996700123456",
        status="ON_THE_WAY",
    )
    db.add(order)
    db.commit()
    db.refresh(order)

    monkeypatch.setattr(
        courier_orders_api,
        "get_delivery_pricing",
        lambda _db: (80, 25, 4, 10),
    )
    result = courier_orders_api.complete_external_admin_order(
        order.id,
        courier_orders_api.ExternalOrderCompleteRequest(distance_km=6),
        db=db,
        current_user=courier,
    )

    db.refresh(order)
    assert order.status == "COMPLETED"
    assert float(order.distance_km) == 6
    assert float(order.price) == 250
    assert float(order.courier_commission) == 5
    assert result["total_price"] == 250
    assert result["courier_commission"] == 5
    assert result["current_balance"] == 95

    db.refresh(courier)
    assert float(courier.balance) == 95
    fee_tx = (
        db.query(Transaction)
        .filter(
            Transaction.order_id == order.id,
            Transaction.type == "SERVICE_FEE_EXTERNAL",
        )
        .one()
    )
    assert float(fee_tx.amount) == -5

    # Retry/double tap must not charge the commission again.
    repeated = courier_orders_api.complete_external_admin_order(
        order.id,
        courier_orders_api.ExternalOrderCompleteRequest(distance_km=6),
        db=db,
        current_user=courier,
    )
    db.refresh(courier)
    assert repeated["courier_commission"] == 5
    assert float(courier.balance) == 95


def test_external_commission_rounds_half_up_to_whole_som():
    assert courier_orders_api._external_order_commission(250) == 5
    assert courier_orders_api._external_order_commission(275) == 6
    assert courier_orders_api._external_order_commission(225) == 5
    assert courier_orders_api._external_order_commission(24) == 0


def test_external_order_acceptance_does_not_create_fixed_hold():
    db = _session()
    admin = _user("+996700000006", "Admin", is_admin=True)
    courier = _user("+996700000007", "Courier", is_courier=True)
    courier.balance = 0
    db.add_all([admin, courier])
    db.commit()

    order = Order(
        user_id=admin.id,
        category="delivery",
        description="Документ",
        from_address="А",
        to_address="Б",
        distance_km=0,
        price=0,
        source="admin_external",
        order_type="delivery",
        customer_phone="+996700123456",
        status="WAITING_COURIER",
    )
    db.add(order)
    db.commit()

    result = courier_orders_api.accept_order(
        order.id,
        db=db,
        current_user=courier,
    )

    db.refresh(order)
    db.refresh(courier)
    assert result["order_id"] == order.id
    assert order.courier_id == courier.id
    assert float(courier.balance) == 0
    assert db.query(Transaction).filter(Transaction.order_id == order.id).count() == 0


def test_existing_fixed_hold_is_adjusted_to_dynamic_commission(monkeypatch):
    db = _session()
    admin = _user("+996700000004", "Admin", is_admin=True)
    courier = _user("+996700000005", "Courier", is_courier=True)
    db.add_all([admin, courier])
    db.commit()

    order = Order(
        user_id=admin.id,
        courier_id=courier.id,
        category="delivery",
        description="Документ",
        from_address="А",
        to_address="Б",
        distance_km=0,
        price=0,
        source="admin_external",
        order_type="delivery",
        customer_phone="+996700123456",
        status="ON_THE_WAY",
    )
    db.add(order)
    db.flush()
    hold_amount(db, courier, order.id, 5)
    db.commit()
    assert float(courier.balance) == 95

    # 275 som produces 5.5, rounded half-up to a 6 som commission.
    monkeypatch.setattr(
        courier_orders_api,
        "get_delivery_pricing",
        lambda _db: (275, 0, 4, 0),
    )
    result = courier_orders_api.complete_external_admin_order(
        order.id,
        courier_orders_api.ExternalOrderCompleteRequest(distance_km=1),
        db=db,
        current_user=courier,
    )

    db.refresh(courier)
    assert result["courier_commission"] == 6
    assert float(courier.balance) == 94
    adjusted = (
        db.query(Transaction)
        .filter(Transaction.order_id == order.id)
        .one()
    )
    assert adjusted.type == "SERVICE_FEE_EXTERNAL"
    assert float(adjusted.amount) == -6
