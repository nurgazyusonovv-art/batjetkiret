from sqlalchemy import (
    Column, Integer, Numeric, String, ForeignKey,
    DateTime, Boolean
)
from sqlalchemy.sql import func
from app.core.database import Base

class TopUpRequest(Base):
    __tablename__ = "topup_requests"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # Nullable until approved
    unique_id = Column(String, nullable=False, index=True)  # User's unique payment ID

    # Telegram bot info
    telegram_user_id = Column(Integer, nullable=False)
    telegram_username = Column(String, nullable=True)
    screenshot_file_id = Column(String, nullable=False)  # Telegram file ID

    # Amount and status
    amount = Column(Numeric(10, 2), nullable=False)
    status = Column(String, default="PENDING")  # PENDING | APPROVED | REJECTED

    # Admin review
    admin_note = Column(String, nullable=True)
    approved_by_admin_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    approved_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, server_default=func.now())
