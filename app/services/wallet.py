from decimal import Decimal

from sqlalchemy.orm import Session

from app.models.user import User
from app.models.transaction import Transaction


def _to_decimal(amount: float | Decimal) -> Decimal:
    return Decimal(str(amount))


def transfer(
    db: Session,
    from_user: User,
    to_user: User,
    amount: float,
):
    amount_decimal = _to_decimal(amount)

    if from_user.balance < amount_decimal:
        raise ValueError("Insufficient balance")

    from_user.balance -= amount_decimal
    to_user.balance += amount_decimal

    db.add(from_user)
    db.add(to_user)


def topup(db: Session, user: User, amount: float):
    amount_decimal = _to_decimal(amount)

    user.balance += amount_decimal
    db.add(
        Transaction(
            user_id=user.id,
            amount=amount_decimal,
            type="TOPUP",
        )
    )
    db.commit()


def hold_amount(db: Session, user: User, order_id: int, amount: float):
    """Reserve `amount` from the user's balance for an order (e.g. courier service fee
    held at acceptance). Creates a HOLD transaction. Caller is responsible for commit."""
    amount_decimal = _to_decimal(amount)

    if user.balance < amount_decimal:
        raise ValueError("Insufficient balance")

    user.balance -= amount_decimal
    db.add(
        Transaction(
            user_id=user.id,
            order_id=order_id,
            amount=-amount_decimal,
            type="HOLD",
        )
    )


def _open_hold(db: Session, user_id: int, order_id: int) -> Transaction | None:
    """Return the active HOLD transaction for (user, order), if any."""
    return (
        db.query(Transaction)
        .filter(
            Transaction.user_id == user_id,
            Transaction.order_id == order_id,
            Transaction.type == "HOLD",
        )
        .first()
    )


def settle_hold(
    db: Session,
    user: User,
    order_id: int,
    final_type: str = "SERVICE_FEE_COURIER",
) -> bool:
    """Finalize a reserved HOLD into a real charge. The money was already moved out
    of balance at hold time, so this only relabels the ledger entry (no balance change).
    Returns True if a hold was settled, False if none existed (e.g. legacy order).
    Caller is responsible for commit."""
    hold = _open_hold(db, user.id, order_id)
    if hold is None:
        return False
    hold.type = final_type
    return True


def release_hold(db: Session, user: User, order_id: int) -> Decimal:
    """Give a reserved HOLD back to the user (order cancelled before completion).
    Idempotent: a second call is a no-op. Returns the released amount.
    Caller is responsible for commit."""
    hold = _open_hold(db, user.id, order_id)
    if hold is None:
        return Decimal("0")

    amount = -hold.amount  # HOLD is stored as a negative amount
    user.balance += amount
    # Relabel so the hold can't be released or settled twice.
    hold.type = "RELEASED"
    db.add(
        Transaction(
            user_id=user.id,
            order_id=order_id,
            amount=amount,
            type="RELEASE",
        )
    )
    return amount


def charge_platform_fee(
    db: Session,
    user: User,
    order_id: int,
    amount: float,
    tx_type: str,
):
    if order_id is None:
        raise ValueError("order_id is required for platform fee transaction")

    amount_decimal = _to_decimal(amount)

    if user.balance < amount_decimal:
        raise ValueError("Insufficient balance")

    user.balance -= amount_decimal
    db.add(
        Transaction(
            user_id=user.id,
            order_id=order_id,
            amount=-amount_decimal,
            type=tx_type,
        )
    )


def payout(db: Session, courier: User, order_id: int, amount: float):
    amount_decimal = _to_decimal(amount)

    courier.balance += amount_decimal
    db.add(
        Transaction(
            user_id=courier.id,
            order_id=order_id,
            amount=amount_decimal,
            type="PAYOUT",
        )
    )
    db.commit()


def refund(db: Session, user: User, order_id: int, amount: float):
    amount_decimal = _to_decimal(amount)

    user.balance += amount_decimal
    db.add(
        Transaction(
            user_id=user.id,
            order_id=order_id,
            amount=amount_decimal,
            type="REFUND",
        )
    )
    db.commit()
