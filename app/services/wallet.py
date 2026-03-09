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
