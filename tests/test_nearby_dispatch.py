"""A taxi ride is offered to drivers around the passenger, nearest first."""

from datetime import datetime, timedelta, timezone

from app.models.order import Order
from app.models.user import User
from app.services.courier_notifications import LOCATION_FRESHNESS, _prefer_nearby

# Batken city centre.
PICKUP = (40.0630, 70.8185)


def _now():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _courier(name, lat=None, lon=None, age=timedelta(minutes=1)):
    return User(
        phone=f"+99670000{abs(hash(name)) % 10000:04d}",
        name=name,
        hashed_password="x",
        is_courier=True,
        is_active=True,
        is_online=True,
        current_latitude=lat,
        current_longitude=lon,
        location_updated_at=None if lat is None else _now() - age,
    )


def _order(lat=PICKUP[0], lon=PICKUP[1]):
    return Order(
        id=1,
        category="taxi",
        from_address="A",
        to_address="B",
        from_latitude=lat,
        from_longitude=lon,
        status="WAITING_COURIER",
    )


def test_nearest_driver_comes_first():
    far = _courier("far", 40.0900, 70.8600)      # ~4-5 km away
    close = _courier("close", 40.0635, 70.8190)  # ~60 m away
    result = _prefer_nearby([far, close], _order())
    assert [c.name for c in result] == ["close", "far"]


def test_drivers_outside_the_radius_are_left_out():
    inside = _courier("inside", 40.0640, 70.8200)
    outside = _courier("outside", 40.2000, 71.0000)  # tens of km away
    result = _prefer_nearby([inside, outside], _order())
    assert [c.name for c in result] == ["inside"]


def test_a_stale_location_does_not_count_as_nearby():
    stale = _courier("stale", 40.0635, 70.8190, age=LOCATION_FRESHNESS * 2)
    result = _prefer_nearby([stale], _order())
    # Nobody qualifies, so the order still goes out to everyone online.
    assert [c.name for c in result] == ["stale"]


def test_everyone_is_offered_when_nobody_is_nearby():
    a = _courier("a", 40.5000, 71.5000)
    b = _courier("b")  # never reported a location
    result = _prefer_nearby([a, b], _order())
    assert {c.name for c in result} == {"a", "b"}


def test_an_order_without_coordinates_goes_to_everyone():
    a = _courier("a", 40.0635, 70.8190)
    b = _courier("b", 40.9000, 71.9000)
    result = _prefer_nearby([a, b], _order(lat=None, lon=None))
    assert {c.name for c in result} == {"a", "b"}
