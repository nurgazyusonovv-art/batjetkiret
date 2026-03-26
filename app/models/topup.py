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
    unique_id = Column(String, nullable=True, index=True)  # User's unique payment ID (set by Telegram bot)

    # Telegram bot info (nullable - only set when request comes from Telegram bot)
    telegram_user_id = Column(Integer, nullable=True)
    telegram_username = Column(String, nullable=True)
    screenshot_file_id = Column(String, nullable=True)  # Telegram file ID

    # Web/REST API fields (nullable - only set when request comes from web)
    screenshot_url = Column(String, nullable=True)
    screenshot_hash = Column(String, nullable=True, index=True)  # SHA256 of screenshot_url for dedup

    # Amount and status
    amount = Column(Numeric(10, 2), nullable=False)
    approved_amount = Column(Numeric(10, 2), nullable=True)  # Actual amount approved by admin
    status = Column(String, default="PENDING")  # PENDING | APPROVED | REJECTED | EXPIRED

    # Admin review
    admin_note = Column(String, nullable=True)
    approved_by_admin_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    approved_at = Column(DateTime, nullable=True)

    expires_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, server_default=func.now())
