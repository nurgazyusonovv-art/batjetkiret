from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime, Float
from sqlalchemy.sql import func
from app.core.database import Base


VALID_CATEGORIES = {
    'food', 'groceries', 'pharmacy', 'clothes',
    'electronics', 'household', 'flowers', 'documents', 'other',
}


class Enterprise(Base):
    __tablename__ = "enterprises"

    id = Column(Integer, primary_key=True, index=True)

    # Basic info
    name = Column(String, nullable=False, index=True)
    category = Column(String, nullable=False)  # food, groceries, pharmacy, ...
    phone = Column(String, nullable=True)
    address = Column(String, nullable=True)
    description = Column(String, nullable=True)
    lat = Column(Float, nullable=True)
    lon = Column(Float, nullable=True)

    # Owner (user who registered it)
    owner_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    # Admin who approved/created (optional)
    created_by_admin_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    is_active = Column(Boolean, default=False)  # Activated by admin after review
    payment_qr_url = Column(String, nullable=True)  # QR code for payment (base64 data URL)

    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
