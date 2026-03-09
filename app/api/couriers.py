from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.models.user import User


router = APIRouter(prefix="/courier", tags=["Courier"])

@router.post("/activate")
def activate_courier(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.is_courier:
        raise HTTPException(status_code=400, detail="Already a courier")

    # Fetch fresh user object from DB to ensure we have the latest state
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.is_courier = True
    db.commit()
    db.refresh(user)
    return {"message": "Courier mode activated"}

@router.post("/deactivate")
def deactivate_courier(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=400, detail="Not a courier")

    # Fetch fresh user object from DB to ensure we have the latest state
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.is_courier = False
    db.commit()
    db.refresh(user)
    return {"message": "Courier mode deactivated"}

@router.get("/me")
def courier_me(
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=403, detail="Not a courier")

    return {
        "id": current_user.id,
        "name": current_user.name,
        "phone": current_user.phone,
        "balance": float(current_user.balance),
    }
