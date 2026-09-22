from sqlalchemy import Column, Integer, String, Boolean, Numeric, DateTime, Float
from sqlalchemy.sql import func
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    is_courier = Column(Boolean, default=False)
    is_admin = Column(Boolean, default=False)

    # Unique reference number for payments (e.g., BJ000123)
    unique_id = Column(String, unique=True, index=True, nullable=True)

    balance = Column(Numeric(10, 2), default=0)
    address = Column(String, nullable=True)
    is_online = Column(Boolean, default=False)
    is_enterprise = Column(Boolean, default=False)  # enterprise portal user
    enterprise_id = Column(Integer, nullable=True)  # linked enterprise (no FK to avoid circular dep)
    courier_transport = Column(
        String,
        nullable=False,
        default="walking",
        server_default="walking",
    )
    courier_vehicle_plate = Column(String, nullable=True)
    courier_vehicle_brand = Column(String, nullable=True)
    courier_vehicle_color = Column(String, nullable=True)

    current_latitude = Column(Float, nullable=True)
    current_longitude = Column(Float, nullable=True)
    # Dispatch only counts a courier as nearby while this is fresh — a location
    # from yesterday says nothing about who can reach the passenger now.
    location_updated_at = Column(DateTime, nullable=True)

    fcm_token = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
