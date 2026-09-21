import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api import users as users_api
from app.core.database import Base
from app.models.user import User


def _session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def _user(*, is_courier: bool) -> User:
    return User(
        phone="+996700000001",
        name="Courier",
        hashed_password="test",
        is_active=True,
        is_courier=is_courier,
        balance=100,
    )


def test_courier_can_save_vehicle_details():
    db = _session()
    courier = _user(is_courier=True)
    db.add(courier)
    db.commit()
    db.refresh(courier)

    result = users_api.update_me(
        users_api.UpdateUserRequest(
            courier_transport="car",
            courier_vehicle_plate=" 01 kg 123 abc ",
            courier_vehicle_brand="  Toyota Camry ",
            courier_vehicle_color=" Ак ",
        ),
        db=db,
        current_user=courier,
    )

    assert result["courier_transport"] == "car"
    assert result["courier_vehicle_plate"] == "01 KG 123 ABC"
    assert result["courier_vehicle_brand"] == "Toyota Camry"
    assert result["courier_vehicle_color"] == "Ак"


def test_car_requires_plate():
    db = _session()
    courier = _user(is_courier=True)
    db.add(courier)
    db.commit()
    db.refresh(courier)

    with pytest.raises(HTTPException) as error:
        users_api.update_me(
            users_api.UpdateUserRequest(courier_transport="cargo"),
            db=db,
            current_user=courier,
        )

    assert error.value.status_code == 400


def test_car_requires_brand_and_color():
    db = _session()
    courier = _user(is_courier=True)
    db.add(courier)
    db.commit()
    db.refresh(courier)

    with pytest.raises(HTTPException) as error:
        users_api.update_me(
            users_api.UpdateUserRequest(
                courier_transport="car",
                courier_vehicle_plate="01 KG 123 ABC",
            ),
            db=db,
            current_user=courier,
        )

    assert error.value.status_code == 400
    assert "маркасын" in error.value.detail
    assert "түсүн" in error.value.detail


def test_non_courier_cannot_change_transport():
    db = _session()
    user = _user(is_courier=False)
    db.add(user)
    db.commit()
    db.refresh(user)

    with pytest.raises(HTTPException) as error:
        users_api.update_me(
            users_api.UpdateUserRequest(courier_transport="scooter"),
            db=db,
            current_user=user,
        )

    assert error.value.status_code == 403
