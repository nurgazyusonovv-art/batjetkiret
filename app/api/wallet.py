from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.models.user import User
from app.models.transaction import Transaction

router = APIRouter(prefix="/wallet", tags=["Wallet"])

# NOTE: There is intentionally no self-service /wallet/topup endpoint. Balance can
# only be credited by an admin after reviewing a payment proof (see /topup/request
# and /admin/topups/{id}/approve). A direct self-topup would let any authenticated
# user mint balance for free.


@router.get("/transactions")
def get_transactions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    transactions = (
        db.query(Transaction)
        .filter(Transaction.user_id == current_user.id)
        .order_by(Transaction.created_at.desc())
        .limit(50)
        .all()
    )
    
    return [
        {
            "id": t.id,
            "amount": float(t.amount),
            "type": t.type,
            "order_id": t.order_id,
            "created_at": t.created_at,
        }
        for t in transactions
    ]
