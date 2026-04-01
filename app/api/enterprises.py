from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime

from app.api.deps import get_db, get_current_user, require_admin
from app.models.enterprise import Enterprise, VALID_CATEGORIES
from app.models.user import User
from app.core.security import hash_password

router = APIRouter(prefix="/enterprises", tags=["Enterprises"])


# ── Schemas ──────────────────────────────────────────────────────────────────

class EnterpriseCreate(BaseModel):
    name: str
    category: str
    phone: Optional[str] = None
    address: Optional[str] = None
    description: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None


class EnterpriseUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    description: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None


def _enterprise_dict(e: Enterprise, owner: Optional[User] = None) -> dict:
    return {
        "id": e.id,
        "name": e.name,
        "category": e.category,
        "phone": e.phone,
        "address": e.address,
        "description": e.description,
        "lat": e.lat,
        "lon": e.lon,
        "is_active": e.is_active,
        "owner_user_id": e.owner_user_id,
        "owner_phone": owner.phone if owner else None,
        "owner_name": owner.name if owner else None,
        "created_by_admin_id": e.created_by_admin_id,
        "created_at": e.created_at,
        "updated_at": e.updated_at,
    }


# ── User endpoints ────────────────────────────────────────────────────────────

@router.post("/register")
def register_enterprise(
    data: EnterpriseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Register a new enterprise. Pending admin activation."""
    if data.category not in VALID_CATEGORIES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid category. Valid: {sorted(VALID_CATEGORIES)}",
        )
    if not data.name.strip():
        raise HTTPException(status_code=400, detail="Name is required")

    enterprise = Enterprise(
        name=data.name.strip(),
        category=data.category,
        phone=data.phone,
        address=data.address,
        description=data.description,
        lat=data.lat,
        lon=data.lon,
        owner_user_id=current_user.id,
        is_active=False,
    )
    db.add(enterprise)
    db.commit()
    db.refresh(enterprise)

    return {
        **_enterprise_dict(enterprise, current_user),
        "message": "Ишканаңыз каттоого жиберилди. Администратор тастыктоосун күтүңүз.",
    }


@router.get("/my")
def my_enterprises(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List enterprises owned by the current user."""
    enterprises = (
        db.query(Enterprise)
        .filter(Enterprise.owner_user_id == current_user.id)
        .order_by(Enterprise.created_at.desc())
        .all()
    )
    return [_enterprise_dict(e, current_user) for e in enterprises]


@router.get("/{enterprise_id}/payment-qr")
def get_enterprise_payment_qr(
    enterprise_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get payment QR URL for an active enterprise (for customers to pay)."""
    enterprise = (
        db.query(Enterprise)
        .filter(Enterprise.id == enterprise_id, Enterprise.is_active == True)  # noqa: E712
        .first()
    )
    if not enterprise:
        raise HTTPException(status_code=404, detail="Ишкана табылган жок")
    return {"payment_qr_url": enterprise.payment_qr_url}


@router.get("/{enterprise_id}/menu")
def get_enterprise_menu(
    enterprise_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get enterprise menu (categories + products) for customers placing orders."""
    from app.models.enterprise_category import EnterpriseCategory
    from app.models.enterprise_product import EnterpriseProduct

    enterprise = (
        db.query(Enterprise)
        .filter(Enterprise.id == enterprise_id, Enterprise.is_active == True)  # noqa: E712
        .first()
    )
    if not enterprise:
        raise HTTPException(status_code=404, detail="Ишкана табылган жок")

    categories = (
        db.query(EnterpriseCategory)
        .filter(
            EnterpriseCategory.enterprise_id == enterprise_id,
            EnterpriseCategory.is_active == True,  # noqa: E712
        )
        .order_by(EnterpriseCategory.sort_order, EnterpriseCategory.id)
        .all()
    )

    menu = []
    for cat in categories:
        products = (
            db.query(EnterpriseProduct)
            .filter(
                EnterpriseProduct.enterprise_id == enterprise_id,
                EnterpriseProduct.category_id == cat.id,
                EnterpriseProduct.is_active == True,  # noqa: E712
            )
            .order_by(EnterpriseProduct.sort_order, EnterpriseProduct.id)
            .all()
        )
        if products:
            menu.append({
                "id": cat.id,
                "name": cat.name,
                "products": [
                    {"id": p.id, "name": p.name, "description": p.description, "price": float(p.price), "image_url": p.image_url}
                    for p in products
                ],
            })

    # Products without a category
    uncategorized = (
        db.query(EnterpriseProduct)
        .filter(
            EnterpriseProduct.enterprise_id == enterprise_id,
            EnterpriseProduct.category_id == None,  # noqa: E711
            EnterpriseProduct.is_active == True,  # noqa: E712
        )
        .order_by(EnterpriseProduct.sort_order, EnterpriseProduct.id)
        .all()
    )
    if uncategorized:
        menu.insert(0, {
            "id": 0,
            "name": "Башка",
            "products": [
                {"id": p.id, "name": p.name, "description": p.description, "price": float(p.price), "image_url": p.image_url}
                for p in uncategorized
            ],
        })

    return {
        "enterprise": {
            "id": enterprise.id,
            "name": enterprise.name,
            "category": enterprise.category,
            "address": enterprise.address,
            "phone": enterprise.phone,
            "description": enterprise.description,
            "lat": enterprise.lat,
            "lon": enterprise.lon,
        },
        "menu": menu,
    }


@router.get("/active")
def list_active_enterprises(
    category: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all active enterprises (optionally filtered by category)."""
    query = db.query(Enterprise).filter(Enterprise.is_active == True)
    if category:
        query = query.filter(Enterprise.category == category)
    enterprises = query.order_by(Enterprise.name).offset(skip).limit(limit).all()

    result = []
    for e in enterprises:
        owner = db.query(User).filter(User.id == e.owner_user_id).first()
        result.append(_enterprise_dict(e, owner))
    return result


# ── Admin endpoints ───────────────────────────────────────────────────────────

@router.get("/admin/list")
def admin_list_enterprises(
    is_active: Optional[bool] = None,
    category: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Admin: list all enterprises with filters."""
    query = db.query(Enterprise)
    if is_active is not None:
        query = query.filter(Enterprise.is_active == is_active)
    if category:
        query = query.filter(Enterprise.category == category)

    enterprises = query.order_by(Enterprise.created_at.desc()).offset(skip).limit(limit).all()

    result = []
    for e in enterprises:
        owner = db.query(User).filter(User.id == e.owner_user_id).first()
        result.append(_enterprise_dict(e, owner))
    return result


@router.get("/admin/{enterprise_id}")
def admin_get_enterprise(
    enterprise_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Admin: get enterprise detail."""
    e = db.query(Enterprise).filter(Enterprise.id == enterprise_id).first()
    if not e:
        raise HTTPException(status_code=404, detail="Enterprise not found")
    owner = db.query(User).filter(User.id == e.owner_user_id).first()
    return _enterprise_dict(e, owner)


@router.put("/admin/{enterprise_id}")
def admin_update_enterprise(
    enterprise_id: int,
    data: EnterpriseUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Admin: update enterprise fields."""
    e = db.query(Enterprise).filter(Enterprise.id == enterprise_id).first()
    if not e:
        raise HTTPException(status_code=404, detail="Enterprise not found")

    if data.name is not None:
        if not data.name.strip():
            raise HTTPException(status_code=400, detail="Name cannot be empty")
        e.name = data.name.strip()
    if data.category is not None:
        if data.category not in VALID_CATEGORIES:
            raise HTTPException(status_code=400, detail="Invalid category")
        e.category = data.category
    if data.phone is not None:
        e.phone = data.phone
    if data.address is not None:
        e.address = data.address
    if data.description is not None:
        e.description = data.description
    if data.lat is not None:
        e.lat = data.lat
    if data.lon is not None:
        e.lon = data.lon

    e.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(e)

    owner = db.query(User).filter(User.id == e.owner_user_id).first()
    return _enterprise_dict(e, owner)


@router.post("/admin/{enterprise_id}/activate")
def admin_activate_enterprise(
    enterprise_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Admin: activate enterprise (make visible to users)."""
    e = db.query(Enterprise).filter(Enterprise.id == enterprise_id).first()
    if not e:
        raise HTTPException(status_code=404, detail="Enterprise not found")
    if e.is_active:
        raise HTTPException(status_code=400, detail="Already active")

    e.is_active = True
    e.created_by_admin_id = admin.id
    e.updated_at = datetime.utcnow()
    db.commit()

    return {"message": "Ишкана активдештирилди", "id": e.id}


@router.post("/admin/{enterprise_id}/deactivate")
def admin_deactivate_enterprise(
    enterprise_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Admin: deactivate enterprise."""
    e = db.query(Enterprise).filter(Enterprise.id == enterprise_id).first()
    if not e:
        raise HTTPException(status_code=404, detail="Enterprise not found")
    if not e.is_active:
        raise HTTPException(status_code=400, detail="Already inactive")

    e.is_active = False
    e.updated_at = datetime.utcnow()
    db.commit()

    return {"message": "Ишкана деактивдештирилди", "id": e.id}


@router.delete("/admin/{enterprise_id}")
def admin_delete_enterprise(
    enterprise_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Admin: permanently delete enterprise."""
    e = db.query(Enterprise).filter(Enterprise.id == enterprise_id).first()
    if not e:
        raise HTTPException(status_code=404, detail="Enterprise not found")

    db.delete(e)
    db.commit()

    return {"message": "Ишкана өчүрүлдү", "id": enterprise_id}


class SetCredentialsRequest(BaseModel):
    phone: str
    password: str
    name: Optional[str] = None


@router.post("/admin/{enterprise_id}/set-credentials")
def admin_set_enterprise_credentials(
    enterprise_id: int,
    data: SetCredentialsRequest,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Admin: create or update login credentials for an enterprise portal user."""
    e = db.query(Enterprise).filter(Enterprise.id == enterprise_id).first()
    if not e:
        raise HTTPException(status_code=404, detail="Enterprise not found")

    # Check if phone already taken by non-enterprise user
    existing = db.query(User).filter(User.phone == data.phone).first()
    if existing and not existing.is_enterprise:
        raise HTTPException(
            status_code=400,
            detail="Бул телефон номери башка колдонуучу тарабынан колдонулуп жатат",
        )

    if existing and existing.is_enterprise and existing.enterprise_id == enterprise_id:
        # Update existing enterprise user's password
        existing.hashed_password = hash_password(data.password)
        if data.name:
            existing.name = data.name
        db.commit()
        return {
            "message": "Сырсөз жаңыланды",
            "user_id": existing.id,
            "phone": existing.phone,
        }

    # Create new enterprise portal user
    new_user = User(
        phone=data.phone,
        name=data.name or e.name,
        hashed_password=hash_password(data.password),
        is_active=True,
        is_courier=False,
        is_admin=False,
        is_enterprise=True,
        enterprise_id=enterprise_id,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {
        "message": "Кирүү маалыматтары түзүлдү",
        "user_id": new_user.id,
        "phone": new_user.phone,
    }


@router.get("/admin/{enterprise_id}/credentials")
def admin_get_enterprise_credentials(
    enterprise_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Admin: get enterprise portal user info (phone only, no password)."""
    ent_user = (
        db.query(User)
        .filter(User.is_enterprise == True, User.enterprise_id == enterprise_id)
        .first()
    )
    if not ent_user:
        return {"has_credentials": False}
    return {
        "has_credentials": True,
        "user_id": ent_user.id,
        "phone": ent_user.phone,
        "name": ent_user.name,
        "is_active": ent_user.is_active,
    }
