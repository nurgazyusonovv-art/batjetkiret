from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
import logging
import random
import string
import secrets

from app.api.deps import get_db, get_current_user
from app.models.user import User
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse
from app.core.security import hash_password, verify_password, create_access_token
from app.core.limiter import limiter
from datetime import datetime, timedelta
from app.models.password_reset import PasswordReset
from app.models.notification import Notification
from app.core.security import generate_reset_code

router = APIRouter(prefix="/auth", tags=["Auth"])
logger = logging.getLogger(__name__)


def generate_unique_id(db: Session) -> str:
    """Generate unique reference ID for user (format: BJ000123)"""
    while True:
        # Generate 6-digit number
        number = random.randint(1, 999999)
        unique_id = f"BJ{number:06d}"
        
        # Check if already exists
        existing = db.query(User).filter(User.unique_id == unique_id).first()
        if not existing:
            return unique_id


def _mask_phone(phone: str) -> str:
    if len(phone) <= 4:
        return "***"
    return f"***{phone[-4:]}"

@router.post("/reset-password")
@limiter.limit("10/minute")
def reset_password(
    request: Request,
    phone: str,
    code: str,
    new_password: str,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.phone == phone).first()
    if not user:
        raise HTTPException(status_code=400)

    reset = (
        db.query(PasswordReset)
        .filter(
            PasswordReset.user_id == user.id,
            PasswordReset.code == code,
            PasswordReset.is_used == False,
        )
        .order_by(PasswordReset.created_at.desc())
        .first()
    )

    if not reset or reset.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invalid or expired code")

    user.hashed_password = hash_password(new_password)
    reset.is_used = True

    db.commit()

    return {"message": "Password updated"}


@router.post("/forgot-password")
@limiter.limit("5/minute")
def forgot_password(request: Request, phone: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.phone == phone).first()

    # Коопсуздук үчүн дайыма бирдей жооп
    if not user:
        return {"message": "If user exists, code sent"}

    now = datetime.utcnow()

    last_reset = (
        db.query(PasswordReset)
        .filter(
            PasswordReset.user_id == user.id,
            PasswordReset.is_used == False,
        )
        .order_by(PasswordReset.created_at.desc())
        .first()
    )

    if last_reset:
        # ⏱ cooldown
        if (now - last_reset.last_sent_at).seconds < 60:
            raise HTTPException(
                status_code=400,
                detail="Please wait before requesting a new code",
            )

        # 🔁 resend лимит
        if last_reset.resend_count >= 3:
            raise HTTPException(
                status_code=400,
                detail="Resend limit reached",
            )

        last_reset.code = generate_reset_code()
        last_reset.resend_count += 1
        last_reset.last_sent_at = now
        last_reset.expires_at = now + timedelta(minutes=10)

        db.commit()

        logger.info("Password reset code resent for phone=%s", _mask_phone(phone))
        return {"message": "Code resent"}

    # Биринчи жолу
    reset = PasswordReset(
        user_id=user.id,
        code=generate_reset_code(),
        expires_at=now + timedelta(minutes=10),
        last_sent_at=now,
    )
    db.add(reset)
    db.commit()

    logger.info("Password reset requested for phone=%s", _mask_phone(phone))
    return {"message": "Reset code sent"}

@router.post("/admin-reset-request")
def admin_reset_request(unique_id: str, db: Session = Depends(get_db)):
    """User enters their unique_id (BJ000123) — system generates code and notifies admins."""
    user = db.query(User).filter(User.unique_id == unique_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Колдонуучу табылган жок. ID номерин текшериңиз.")

    # Generate 6-digit code
    code = "".join([str(random.randint(0, 9)) for _ in range(6)])
    now = datetime.utcnow()

    # Reuse or create PasswordReset record
    existing = (
        db.query(PasswordReset)
        .filter(PasswordReset.user_id == user.id, PasswordReset.is_used == False)
        .order_by(PasswordReset.created_at.desc())
        .first()
    )
    if existing:
        existing.code = code
        existing.expires_at = now + timedelta(hours=24)
        existing.last_sent_at = now
    else:
        db.add(PasswordReset(
            user_id=user.id,
            code=code,
            expires_at=now + timedelta(hours=24),
            last_sent_at=now,
        ))

    # Notify all admins
    admins = db.query(User).filter(User.is_admin == True).all()  # noqa: E712
    for admin in admins:
        db.add(Notification(
            user_id=admin.id,
            title="🔑 Сырсөздү баштан коюу суранычы",
            message=f"Колдонуучу {unique_id} ({user.phone}) сырсөздү унутту. Ага берилүүчү код: {code}",
            notification_type="ADMIN_MESSAGE",
        ))

    db.commit()
    return {"ok": True}


@router.post("/admin-reset-confirm")
def admin_reset_confirm(unique_id: str, code: str, db: Session = Depends(get_db)):
    """Verify code, generate new random password, return it."""
    user = db.query(User).filter(User.unique_id == unique_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Колдонуучу табылган жок")

    reset = (
        db.query(PasswordReset)
        .filter(
            PasswordReset.user_id == user.id,
            PasswordReset.code == code,
            PasswordReset.is_used == False,
        )
        .order_by(PasswordReset.created_at.desc())
        .first()
    )
    if not reset or reset.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Код туура эмес же мөөнөтү өткөн")

    # Generate new readable password: 4 letters + 4 digits
    letters = ''.join(secrets.choice(string.ascii_lowercase) for _ in range(4))
    digits_part = ''.join(secrets.choice(string.digits) for _ in range(4))
    new_password = letters + digits_part

    user.hashed_password = hash_password(new_password)
    reset.is_used = True
    db.commit()

    return {"new_password": new_password}


@router.post("/register", response_model=TokenResponse)
@limiter.limit("20/minute")
def register(request: Request, data: RegisterRequest, db: Session = Depends(get_db)):
    if db.query(User).filter(User.phone == data.phone).first():
        raise HTTPException(
            status_code=400,
            detail="Phone already registered"
        )

    user = User(
        phone=data.phone,
        name=data.name,
        hashed_password=hash_password(data.password),
        is_courier=data.is_courier,
        balance=200,  # Welcome bonus for new users
        unique_id=generate_unique_id(db)  # Generate unique payment reference ID
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "phone": user.phone,
            "name": user.name,
            "role": "admin" if user.is_admin else ("courier" if user.is_courier else "user"),
            "is_active": user.is_active,
            "is_courier": user.is_courier,
            "balance": float(user.balance),
            "created_at": user.created_at.isoformat() if user.created_at else None,
        }
    }

@router.post("/login", response_model=TokenResponse)
@limiter.limit("30/minute")
def login(request: Request, data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.phone == data.phone).first()
    if not user or not verify_password(data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )

    token = create_access_token(user.id)
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "phone": user.phone,
            "name": user.name,
            "role": "admin" if user.is_admin else ("courier" if user.is_courier else "user"),
            "is_active": user.is_active,
            "is_courier": user.is_courier,
            "balance": float(user.balance),
            "created_at": user.created_at.isoformat() if user.created_at else None,
        }
    }

@router.post("/change-password")
def change_password(
    old_password: str,
    new_password: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """User changes their own password"""
    if not verify_password(old_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect password")

    current_user.hashed_password = hash_password(new_password)
    db.commit()

    logger.info("Password changed for user=%s", _mask_phone(current_user.phone))
    return {"message": "Password changed successfully"}
