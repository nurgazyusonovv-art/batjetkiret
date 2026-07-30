from sqlalchemy import Column, Integer, String, Text, Numeric, DateTime, ForeignKey
from sqlalchemy.sql import func

from app.core.database import Base


class Advertisement(Base):
    __tablename__ = "advertisements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    title = Column(String(120), nullable=False)
    description = Column(Text, nullable=False)
    category = Column(String(80), nullable=True)
    contact_phone = Column(String(32), nullable=True)
    image_url = Column(Text, nullable=True)

    status = Column(String(20), nullable=False, default="PENDING", index=True)
    duration_days = Column(Integer, nullable=False, default=7)
    fee_amount = Column(Numeric(10, 2), nullable=False, default=0)
    view_count = Column(Integer, nullable=False, default=0)
    rejection_reason = Column(Text, nullable=True)

    approved_by_admin_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    approved_at = Column(DateTime, nullable=True)
    starts_at = Column(DateTime, nullable=True)
    expires_at = Column(DateTime, nullable=True, index=True)

    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
