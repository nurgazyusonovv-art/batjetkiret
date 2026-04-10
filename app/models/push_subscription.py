from sqlalchemy import Column, Integer, Text, DateTime
from sqlalchemy.sql import func
from app.core.database import Base


class PushSubscription(Base):
    __tablename__ = "push_subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    enterprise_id = Column(Integer, nullable=False, index=True)
    subscription_json = Column(Text, nullable=False)  # Full PushSubscription JSON from browser
    created_at = Column(DateTime, server_default=func.now())
