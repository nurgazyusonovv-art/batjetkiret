from sqlalchemy import Column, Integer, String, Boolean, Numeric, DateTime
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

    created_at = Column(DateTime, server_default=func.now())
