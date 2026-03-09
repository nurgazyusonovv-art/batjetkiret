from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.models.rating import CourierRating
from app.models.order import Order
from app.models.user import User
from sqlalchemy import func

from app.models.user_rating import UserRating

router = APIRouter(prefix="/ratings", tags=["Ratings"])


@router.get("/status/{order_id}")
def get_rating_status(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if current_user.id not in [order.user_id, order.courier_id]:
        raise HTTPException(status_code=403, detail="Access denied")

    if order.status != "COMPLETED":
        return {"rated": False}

    if current_user.id == order.user_id:
        rated = (
            db.query(CourierRating)
            .filter(CourierRating.order_id == order.id)
            .first()
            is not None
        )
        return {"rated": rated}

    if current_user.id == order.courier_id:
        rated = (
            db.query(UserRating)
            .filter(UserRating.order_id == order.id)
            .first()
            is not None
        )
        return {"rated": rated}

    return {"rated": False}

@router.post("/courier/{order_id}")
def rate_courier(
    order_id: int,
    rating: int,
    comment: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if rating < 1 or rating > 5:
        raise HTTPException(status_code=400, detail="Rating must be 1–5")

    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404)

    if order.user_id != current_user.id:
        raise HTTPException(status_code=403)

    if order.status != "COMPLETED":
        raise HTTPException(status_code=400, detail="Order not completed")

    existing = (
        db.query(CourierRating)
        .filter(CourierRating.order_id == order_id)
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Already rated")

    rating_obj = CourierRating(
        order_id=order.id,
        courier_id=order.courier_id,
        user_id=current_user.id,
        rating=rating,
        comment=comment,
    )

    db.add(rating_obj)
    db.commit()

    return {"message": "Courier rated successfully"}



@router.get("/courier/me")
def my_ratings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=403)

    avg_rating = (
        db.query(func.coalesce(func.avg(CourierRating.rating), 0))
        .filter(CourierRating.courier_id == current_user.id)
        .scalar()
    )

    total = (
        db.query(func.count(CourierRating.id))
        .filter(CourierRating.courier_id == current_user.id)
        .scalar()
    )

    return {
        "average_rating": round(float(avg_rating), 2),
        "total_reviews": total,
    }

@router.post("/user/{order_id}")
def rate_user(
    order_id: int,
    rating: int,
    comment: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user.is_courier:
        raise HTTPException(status_code=403)

    if rating < 1 or rating > 5:
        raise HTTPException(status_code=400)

    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404)

    if order.courier_id != current_user.id:
        raise HTTPException(status_code=403)

    if order.status != "COMPLETED":
        raise HTTPException(status_code=400, detail="Order not completed")

    existing = (
        db.query(UserRating)
        .filter(UserRating.order_id == order_id)
        .first()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Already rated")

    r = UserRating(
        order_id=order.id,
        rater_id=current_user.id,
        target_user_id=order.user_id,
        rating=rating,
        comment=comment,
    )
    db.add(r)
    db.commit()

    return {"message": "User rated successfully"}


@router.get("/user/me")
def my_user_rating(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from sqlalchemy import func

    avg = (
        db.query(func.coalesce(func.avg(UserRating.rating), 0))
        .filter(UserRating.target_user_id == current_user.id)
        .scalar()
    )

    total = (
        db.query(func.count(UserRating.id))
        .filter(UserRating.target_user_id == current_user.id)
        .scalar()
    )

    return {
        "average_rating": round(float(avg), 2),
        "total_reviews": total,
    }

