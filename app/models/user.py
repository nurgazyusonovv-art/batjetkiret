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

    current_latitude = Column(Float, nullable=True)
    current_longitude = Column(Float, nullable=True)

    fcm_token = Column(String, nullable=True)

    created_at = Column(DateTime, server_default=func.now())
