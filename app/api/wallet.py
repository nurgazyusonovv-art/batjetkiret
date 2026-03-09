from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.services.wallet import topup
from app.models.user import User
from app.models.transaction import Transaction

router = APIRouter(prefix="/wallet", tags=["Wallet"])

@router.post("/topup")
def wallet_topup(
    amount: float,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Толуктоо суммасы оң болушу керек")
    
    if amount < 10:
        raise HTTPException(status_code=400, detail="Минималдуу толуктоо суммасы 10 сом")
    
    topup(db, current_user, amount)
    return {"balance": float(current_user.balance)}


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
