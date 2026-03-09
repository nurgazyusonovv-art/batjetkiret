from sqlalchemy import Column, Integer, ForeignKey, SmallInteger, String, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class CourierRating(Base):
    __tablename__ = "courier_ratings"

    id = Column(Integer, primary_key=True, index=True)

    order_id = Column(Integer, ForeignKey("orders.id"), unique=True)
    courier_id = Column(Integer, ForeignKey("users.id"))
    user_id = Column(Integer, ForeignKey("users.id"))

    rating = Column(SmallInteger, nullable=False)  # 1–5
    comment = Column(String, nullable=True)

    created_at = Column(DateTime, server_default=func.now())
