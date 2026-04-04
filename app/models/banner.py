from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime
from datetime import datetime, timezone
from app.core.database import Base


class Banner(Base):
    __tablename__ = "banners"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=True)
    subtitle = Column(String, nullable=True)
    image_data = Column(Text, nullable=True)   # base64 data URL
    link_url = Column(String, nullable=True)   # external URL (optional)
    is_active = Column(Boolean, default=True, nullable=False)
    sort_order = Column(Integer, default=0, nullable=False)
    view_count = Column(Integer, default=0, nullable=False)
    show_days = Column(Integer, default=0, nullable=False)   # 0 = unlimited
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
