from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey
from sqlalchemy.sql import func
from app.core.database import Base

class PasswordReset(Base):
    __tablename__ = "password_resets"

    id = Column(Integer, primary_key=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    code = Column(String, nullable=False)

    is_used = Column(Boolean, default=False)
    expires_at = Column(DateTime, nullable=False)

    resend_count = Column(Integer, default=0)
    last_sent_at = Column(DateTime, nullable=False)

    created_at = Column(DateTime, server_default=func.now())
