"""The billed distance comes from the server, not from what the app sends."""

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api import orders as orders_api
from app.core.database import Base
from app.models.user import User
from app.schemas.order import OrderCreateRequest
from app.services import pricing
from app.services.pricing import ROAD_FACTOR, haversine_km, resolve_distance_km

# Two points in Batken: ~1.25 km apart in a straight line.
FROM_LAT, FROM_LON = 40.0630, 70.8185
TO_LAT, TO_LON = 40.0700, 70.8300


@pytest.fixture
def offline_routing(monkeypatch):
    """No routing key → straight line × road factor, and no network calls."""
    monkeypatch.setattr(pricing.settings, "ORS_API_KEY", "")


def _session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def test_client_distance_is_ignored_when_coordinates_are_present(offline_routing):
    expected = haversine_km(FROM_LAT, FROM_LON, TO_LAT, TO_LON) * ROAD_FACTOR

    honest = resolve_distance_km(1.25, FROM_LAT, FROM_LON, TO_LAT, TO_LON)
    tampered = resolve_distance_km(0.5, FROM_LAT, FROM_LON, TO_LAT, TO_LON)

    assert honest == pytest.approx(expected, rel=0.01)
    assert tampered == pytest.approx(expected, rel=0.01)


def test_client_distance_is_clamped_when_coordinates_are_missing(offline_routing):
    assert resolve_distance_km(0.1, None, None, None, None) == 0.5
    assert resolve_distance_km(9000, None, None, None, None) == 500.0
    assert resolve_distance_km(3.2, None, None, None, None) == pytest.approx(3.2)


def test_created_order_is_priced_on_the_server_distance(offline_routing):
    db = _session()
    user = User(
        phone="+996700000010",
        name="Customer",
        hashed_password="test",
        is_active=True,
        balance=500,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    request = OrderCreateRequest(
        category="taxi",
        description="Тест заказ",
        from_address="улица И. Разаков, Баткен, 12",
        to_address="улица И. Разаков, Баткен, 7",
        from_latitude=FROM_LAT,
        from_longitude=FROM_LON,
        to_latitude=TO_LAT,
        to_longitude=TO_LON,
        distance_km=0.5,  # tampered: far shorter than the real route
    )

    response = orders_api.create_order(request, db, user)

    expected = haversine_km(FROM_LAT, FROM_LON, TO_LAT, TO_LON) * ROAD_FACTOR
    base, per_km, extra_after_km, extra_per_km = orders_api.get_taxi_pricing(db)
    expected_price = pricing.calculate_price(
        expected, base, per_km, extra_after_km, extra_per_km
    )

    order = db.query(orders_api.Order).filter_by(id=response["id"]).first()
    assert float(order.distance_km) == pytest.approx(expected, rel=0.01)
    assert response["price"] == pytest.approx(expected_price, rel=0.01)
    # The tampered distance would have been much cheaper.
    assert response["price"] > pricing.calculate_price(
        0.5, base, per_km, extra_after_km, extra_per_km
    )
