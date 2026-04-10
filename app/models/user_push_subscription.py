from sqlalchemy import Column, Integer, Text, DateTime
from sqlalchemy.sql import func
from app.core.database import Base


class UserPushSubscription(Base):
    __tablename__ = "user_push_subscriptions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    subscription_json = Column(Text, nullable=False)
    created_at = Column(DateTime, server_default=func.now())
