from sqlalchemy import Column, Integer, String, Numeric, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class OrderPayment(Base):
    __tablename__ = "order_payments"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False, unique=True)
    enterprise_id = Column(Integer, ForeignKey("enterprises.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    amount = Column(Numeric(10, 2), nullable=False)
    screenshot_url = Column(String, nullable=True)   # base64 data URL
    status = Column(String, default="pending")        # pending | confirmed | rejected
    note = Column(String, nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    order = relationship("Order", foreign_keys=[order_id])
    user = relationship("User", foreign_keys=[user_id])
