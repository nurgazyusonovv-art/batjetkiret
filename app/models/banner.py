from sqlalchemy import Column, Integer, String, Text, Boolean
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
