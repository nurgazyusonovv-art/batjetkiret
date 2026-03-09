from sqlalchemy import Column, Integer, Numeric, String, ForeignKey, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=True)

    amount = Column(Numeric(10, 2), nullable=False)
    type = Column(String, nullable=False)
    # TOPUP | HOLD | RELEASE | PAYOUT | SERVICE_FEE_USER | SERVICE_FEE_COURIER

    created_at = Column(DateTime, server_default=func.now())
