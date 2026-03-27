from pydantic import BaseModel, Field, field_validator
from typing import Optional

class OrderCreateRequest(BaseModel):
    category: str = Field(..., min_length=1, max_length=100)
    description: str = Field(..., min_length=1, max_length=500)
    from_address: str = Field(..., min_length=1, max_length=255)
    to_address: str = Field(..., min_length=1, max_length=255)
    from_latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    from_longitude: Optional[float] = Field(default=None, ge=-180, le=180)
    to_latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    to_longitude: Optional[float] = Field(default=None, ge=-180, le=180)
    distance_km: float = Field(default=1.0, ge=0, le=10000)
    enterprise_id: Optional[int] = None
    intercity_city_id: Optional[int] = None

class OrderResponse(BaseModel):
    id: int
    price: float
    status: str
    from_latitude: Optional[float] = None
    from_longitude: Optional[float] = None
    to_latitude: Optional[float] = None
    to_longitude: Optional[float] = None
