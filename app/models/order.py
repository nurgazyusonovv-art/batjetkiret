from sqlalchemy import Column, Integer, String, Numeric, ForeignKey, DateTime, Text, Boolean
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    courier_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    
    # Relationships for eager loading
    user = relationship("User", foreign_keys=[user_id], lazy="joined")
    courier = relationship("User", foreign_keys=[courier_id], lazy="joined")

    category = Column(String, nullable=False)

    description = Column(Text, nullable=False)

    from_address = Column(String, nullable=False)
    to_address = Column(String, nullable=False)

    # Coordinates are stored separately from text addresses.
    from_latitude = Column(Numeric(10, 7), nullable=True)
    from_longitude = Column(Numeric(10, 7), nullable=True)
    to_latitude = Column(Numeric(10, 7), nullable=True)
    to_longitude = Column(Numeric(10, 7), nullable=True)

    distance_km = Column(Numeric(5, 2), nullable=False)
    price = Column(Numeric(10, 2), nullable=False)
    
    # Commission tracking
    user_commission = Column(Numeric(10, 2), nullable=True, default=0)  # Commission from user
    courier_commission = Column(Numeric(10, 2), nullable=True, default=0)  # Commission from courier

    enterprise_id = Column(Integer, ForeignKey("enterprises.id"), nullable=True)
    source = Column(String, default="online")    # 'online' | 'local' | 'dine_in'
    order_type = Column(String, default="delivery")  # 'delivery' | 'dine_in'
    table_number = Column(String, nullable=True)

    status = Column(String, default="WAITING_COURIER")
    admin_note = Column(Text, nullable=True)
    verification_code = Column(String(6), nullable=True)

    # Soft delete flags for separate history visibility
    hidden_for_user = Column(Boolean, default=False, nullable=False)
    hidden_for_courier = Column(Boolean, default=False, nullable=False)
    hidden_for_enterprise = Column(Boolean, default=False, nullable=False)

    created_at = Column(DateTime, server_default=func.now())
