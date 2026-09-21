from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.sql import func
from app.core.database import Base

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    title = Column(String, nullable=False)
    message = Column(String, nullable=False)

    related_chat_id = Column(Integer, nullable=True)
    order_id = Column(Integer, nullable=True)

    # Rich notifications (admin campaigns): a picture plus the enterprise the
    # notification advertises, so tapping it opens that shop.
    image_url = Column(String, nullable=True)
    enterprise_id = Column(
        Integer,
        ForeignKey("enterprises.id", ondelete="SET NULL"),
        nullable=True,
    )
    notification_type = Column(String, nullable=True)

    is_read = Column(Boolean, default=False)

    created_at = Column(DateTime, server_default=func.now())
