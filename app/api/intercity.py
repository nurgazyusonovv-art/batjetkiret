from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.models.intercity_city import IntercityCity

router = APIRouter(prefix="/intercity", tags=["Intercity"])


@router.get("/cities")
def list_cities(
    db: Session = Depends(get_db),
    _=Depends(get_current_user),
):
    cities = (
        db.query(IntercityCity)
        .filter(IntercityCity.is_active == True)  # noqa: E712
        .order_by(IntercityCity.name)
        .all()
    )
    return [
        {"id": c.id, "name": c.name, "price": float(c.price)}
        for c in cities
    ]
