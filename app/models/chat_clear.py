from sqlalchemy import Column, Integer, ForeignKey, UniqueConstraint
from app.core.database import Base


class ChatClear(Base):
    """Per-user "clear chat" marker. Messages with id <= cleared_message_id are
    hidden from that user only (the other participant still sees them)."""

    __tablename__ = "chat_clears"

    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(Integer, ForeignKey("chat_rooms.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    cleared_message_id = Column(Integer, nullable=False, default=0)

    __table_args__ = (
        UniqueConstraint("chat_id", "user_id", name="uq_chat_clear_user"),
    )
