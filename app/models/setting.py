from sqlalchemy import Column, String, Text
from app.core.database import Base


class Setting(Base):
    """Key-value store for system-wide settings managed by admin."""
    __tablename__ = "settings"

    key = Column(String, primary_key=True, index=True)
    value = Column(Text, nullable=False)
    description = Column(Text, nullable=True)
