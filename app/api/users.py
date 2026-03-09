from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.models.user import User

router = APIRouter(prefix="/users", tags=["Users"])

class UpdateUserRequest(BaseModel):
    name: str | None = None
    phone: str | None = None
    address: str | None = None
    is_online: bool | None = None

@router.get("/me")
def get_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return {
        "id": current_user.id,
        "phone": current_user.phone,
        "name": current_user.name,
        "is_courier": current_user.is_courier,
        "is_admin": current_user.is_admin,
        "balance": float(current_user.balance or 0),
        "address": current_user.address,
        "is_online": current_user.is_online,
        "unique_id": current_user.unique_id,
        "created_at": current_user.created_at,
    }

@router.put("/me")
def update_me(
    request: UpdateUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Fetch fresh user object from DB
    user = db.query(User).filter(User.id == current_user.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Update fields if provided
    if request.name:
        user.name = request.name
    if request.phone:
        # Check if phone is already taken by another user
        existing_user = db.query(User).filter(
            User.phone == request.phone,
            User.id != user.id
        ).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Phone already in use")
        user.phone = request.phone
    if request.address is not None:
        user.address = request.address
    if request.is_online is not None:
        user.is_online = request.is_online

    db.commit()
    db.refresh(user)

    return {
        "id": user.id,
        "phone": user.phone,
        "name": user.name,
        "is_courier": user.is_courier,
        "is_admin": user.is_admin,
        "balance": float(user.balance or 0),
        "address": user.address,
        "is_online": user.is_online,
        "created_at": user.created_at,
    }
