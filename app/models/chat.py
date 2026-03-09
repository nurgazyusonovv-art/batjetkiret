from sqlalchemy import Column, Integer, ForeignKey, DateTime, String
from sqlalchemy.sql import func
from app.core.database import Base

class ChatRoom(Base):
    __tablename__ = "chat_rooms"

    id = Column(Integer, primary_key=True, index=True)

    type = Column(String, nullable=False)
    # ORDER | SUPPORT

    order_id = Column(Integer, ForeignKey("orders.id"), nullable=True)

    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    courier_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    admin_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    created_at = Column(DateTime, server_default=func.now())
