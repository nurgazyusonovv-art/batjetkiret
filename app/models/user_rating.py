from sqlalchemy import Column, Integer, ForeignKey, SmallInteger, String, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class UserRating(Base):
    __tablename__ = "user_ratings"

    id = Column(Integer, primary_key=True, index=True)

    order_id = Column(Integer, ForeignKey("orders.id"), unique=True)

    rater_id = Column(Integer, ForeignKey("users.id"))      # ким баалады
    target_user_id = Column(Integer, ForeignKey("users.id")) # кимге берилди

    rating = Column(SmallInteger, nullable=False)  # 1–5
    comment = Column(String, nullable=True)

    created_at = Column(DateTime, server_default=func.now())
