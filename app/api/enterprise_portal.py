"""
Enterprise Portal API
All endpoints require is_enterprise=True user with active enterprise.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func, cast, Date
from typing import Optional, Tuple, List
from decimal import Decimal
from datetime import datetime, timedelta, date

from fastapi import UploadFile, File
from app.api.deps import get_db, require_enterprise, get_current_user
from app.core.security import verify_password, create_access_token
from app.models.user import User
from app.models.order import Order
from app.models.enterprise import Enterprise
from app.models.enterprise_category import EnterpriseCategory
from app.models.enterprise_product import EnterpriseProduct
from app.models.order_payment import OrderPayment

router = APIRouter(prefix="/enterprise-portal", tags=["Enterprise Portal"])


# ── Auth ──────────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    phone: str
    password: str


@router.post("/login")
def enterprise_login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.phone == data.phone).first()
    if not user or not verify_password(data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Телефон же сырсөз туура эмес")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Каттоо эсеби бөгөттөлгөн")
    if not user.is_enterprise or not user.enterprise_id:
        raise HTTPException(status_code=403, detail="Бул аккаунт ишкана колдонуучусу эмес")

    enterprise = db.query(Enterprise).filter(Enterprise.id == user.enterprise_id).first()
    if not enterprise:
        raise HTTPException(status_code=404, detail="Ишкана табылган жок")
    if not enterprise.is_active:
        raise HTTPException(status_code=403, detail="Ишкана активдүү эмес. Администратор менен байланышыңыз.")

    return {
        "access_token": create_access_token(user.id),
        "token_type": "bearer",
        "enterprise": {
            "enterprise_id": enterprise.id,
            "enterprise_name": enterprise.name,
            "category": enterprise.category,
            "user_id": user.id,
            "phone": user.phone,
        },
    }


# ── Enterprise info ───────────────────────────────────────────────────────────

@router.get("/me")
def get_my_enterprise(db: Session = Depends(get_db), auth: Tuple = Depends(require_enterprise)):
    _user, e = auth
    return {
        "id": e.id, "name": e.name, "category": e.category,
        "phone": e.phone, "address": e.address, "description": e.description,
        "lat": e.lat, "lon": e.lon, "is_active": e.is_active,
        "payment_qr_url": e.payment_qr_url,
    }


# ── Categories ────────────────────────────────────────────────────────────────

class CategoryCreate(BaseModel):
    name: str
    sort_order: int = 0

class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


def _cat_dict(c: EnterpriseCategory) -> dict:
    return {"id": c.id, "name": c.name, "sort_order": c.sort_order,
            "is_active": c.is_active, "created_at": c.created_at}


@router.get("/categories")
def list_categories(db: Session = Depends(get_db), auth: Tuple = Depends(require_enterprise)):
    _user, e = auth
    cats = (db.query(EnterpriseCategory)
            .filter(EnterpriseCategory.enterprise_id == e.id)
            .order_by(EnterpriseCategory.sort_order, EnterpriseCategory.id)
            .all())
    return [_cat_dict(c) for c in cats]


@router.post("/categories")
def create_category(data: CategoryCreate, db: Session = Depends(get_db), auth: Tuple = Depends(require_enterprise)):
    _user, e = auth
    if not data.name.strip():
        raise HTTPException(status_code=400, detail="Категория аты талап кылынат")
    cat = EnterpriseCategory(enterprise_id=e.id, name=data.name.strip(), sort_order=data.sort_order)
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return _cat_dict(cat)


@router.put("/categories/{cat_id}")
def update_category(cat_id: int, data: CategoryUpdate, db: Session = Depends(get_db), auth: Tuple = Depends(require_enterprise)):
    _user, e = auth
    cat = db.query(EnterpriseCategory).filter(
        EnterpriseCategory.id == cat_id, EnterpriseCategory.enterprise_id == e.id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Категория табылган жок")
    if data.name is not None:
        cat.name = data.name.strip()
    if data.sort_order is not None:
        cat.sort_order = data.sort_order
    if data.is_active is not None:
        cat.is_active = data.is_active
    db.commit()
    db.refresh(cat)
    return _cat_dict(cat)


@router.delete("/categories/{cat_id}")
def delete_category(cat_id: int, db: Session = Depends(get_db), auth: Tuple = Depends(require_enterprise)):
    _user, e = auth
    cat = db.query(EnterpriseCategory).filter(
        EnterpriseCategory.id == cat_id, EnterpriseCategory.enterprise_id == e.id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Категория табылган жок")
    # Move products to uncategorized
    db.query(EnterpriseProduct).filter(
        EnterpriseProduct.category_id == cat_id).update({"category_id": None})
    db.delete(cat)
    db.commit()
    return {"message": "Категория өчүрүлдү"}


# ── Products ──────────────────────────────────────────────────────────────────

class ProductCreate(BaseModel):
    name: str
    price: float
    description: Optional[str] = None
    category_id: Optional[int] = None
    sort_order: int = 0

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    price: Optional[float] = None
    description: Optional[str] = None
    category_id: Optional[int] = None
    sort_order: Optional[int] = None
    is_active: Optional[bool] = None


def _prod_dict(p: EnterpriseProduct, category_name: Optional[str] = None) -> dict:
    return {
        "id": p.id, "name": p.name, "description": p.description,
        "price": float(p.price), "is_active": p.is_active,
        "sort_order": p.sort_order, "category_id": p.category_id,
        "category_name": category_name, "created_at": p.created_at,
    }


@router.get("/products")
def list_products(
    category_id: Optional[int] = None,
    active_only: bool = False,
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    _user, e = auth
    q = db.query(EnterpriseProduct).filter(EnterpriseProduct.enterprise_id == e.id)
    if category_id is not None:
        q = q.filter(EnterpriseProduct.category_id == category_id)
    if active_only:
        q = q.filter(EnterpriseProduct.is_active == True)
    products = q.order_by(EnterpriseProduct.category_id, EnterpriseProduct.sort_order, EnterpriseProduct.id).all()

    # Fetch category names in one query
    cat_ids = {p.category_id for p in products if p.category_id}
    cats = {c.id: c.name for c in db.query(EnterpriseCategory).filter(EnterpriseCategory.id.in_(cat_ids)).all()} if cat_ids else {}

    return [_prod_dict(p, cats.get(p.category_id)) for p in products]


@router.post("/products")
def create_product(data: ProductCreate, db: Session = Depends(get_db), auth: Tuple = Depends(require_enterprise)):
    _user, e = auth
    if not data.name.strip():
        raise HTTPException(status_code=400, detail="Товардын аты талап кылынат")
    if data.price < 0:
        raise HTTPException(status_code=400, detail="Баасы терс болушу мүмкүн эмес")

    # Verify category belongs to this enterprise
    if data.category_id:
        cat = db.query(EnterpriseCategory).filter(
            EnterpriseCategory.id == data.category_id,
            EnterpriseCategory.enterprise_id == e.id).first()
        if not cat:
            raise HTTPException(status_code=400, detail="Категория табылган жок")

    prod = EnterpriseProduct(
        enterprise_id=e.id,
        category_id=data.category_id,
        name=data.name.strip(),
        description=data.description,
        price=Decimal(str(data.price)),
        sort_order=data.sort_order,
    )
    db.add(prod)
    db.commit()
    db.refresh(prod)
    cat_name = None
    if prod.category_id:
        c = db.query(EnterpriseCategory).filter(EnterpriseCategory.id == prod.category_id).first()
        cat_name = c.name if c else None
    return _prod_dict(prod, cat_name)


@router.put("/products/{prod_id}")
def update_product(prod_id: int, data: ProductUpdate, db: Session = Depends(get_db), auth: Tuple = Depends(require_enterprise)):
    _user, e = auth
    prod = db.query(EnterpriseProduct).filter(
        EnterpriseProduct.id == prod_id, EnterpriseProduct.enterprise_id == e.id).first()
    if not prod:
        raise HTTPException(status_code=404, detail="Товар табылган жок")

    if data.name is not None:
        prod.name = data.name.strip()
    if data.price is not None:
        prod.price = Decimal(str(data.price))
    if data.description is not None:
        prod.description = data.description
    if data.sort_order is not None:
        prod.sort_order = data.sort_order
    if data.is_active is not None:
        prod.is_active = data.is_active
    if data.category_id is not None:
        if data.category_id == 0:
            prod.category_id = None
        else:
            cat = db.query(EnterpriseCategory).filter(
                EnterpriseCategory.id == data.category_id,
                EnterpriseCategory.enterprise_id == e.id).first()
            if not cat:
                raise HTTPException(status_code=400, detail="Категория табылган жок")
            prod.category_id = data.category_id

    db.commit()
    db.refresh(prod)
    cat_name = None
    if prod.category_id:
        c = db.query(EnterpriseCategory).filter(EnterpriseCategory.id == prod.category_id).first()
        cat_name = c.name if c else None
    return _prod_dict(prod, cat_name)


@router.delete("/products/{prod_id}")
def delete_product(prod_id: int, db: Session = Depends(get_db), auth: Tuple = Depends(require_enterprise)):
    _user, e = auth
    prod = db.query(EnterpriseProduct).filter(
        EnterpriseProduct.id == prod_id, EnterpriseProduct.enterprise_id == e.id).first()
    if not prod:
        raise HTTPException(status_code=404, detail="Товар табылган жок")
    db.delete(prod)
    db.commit()
    return {"message": "Товар өчүрүлдү"}


# ── Orders ────────────────────────────────────────────────────────────────────

class OrderItemIn(BaseModel):
    product_id: int
    quantity: int = 1

class LocalOrderCreate(BaseModel):
    order_type: str = "delivery"   # 'delivery' | 'dine_in'
    customer_phone: Optional[str] = None   # delivery үчүн милдеттүү
    table_number: Optional[str] = None     # dine_in үчүн (мис: "3")
    to_address: Optional[str] = None       # delivery үчүн милдеттүү
    to_lat: Optional[float] = None
    to_lng: Optional[float] = None
    items: List[OrderItemIn]
    note: Optional[str] = None


def _order_dict(o: Order) -> dict:
    return {
        "id": o.id,
        "user_phone": o.user.phone if o.user else None,
        "user_name": o.user.name if o.user else None,
        "courier_name": o.courier.name if o.courier else None,
        "courier_phone": o.courier.phone if o.courier else None,
        "from_address": o.from_address,
        "to_address": o.to_address,
        "table_number": getattr(o, 'table_number', None),
        "category": o.category,
        "description": o.description,
        "price": float(o.price),
        "items_total": float(o.items_total) if o.items_total is not None else None,
        "status": o.status,
        "source": getattr(o, 'source', 'online'),
        "order_type": getattr(o, 'order_type', 'delivery'),
        "created_at": o.created_at.isoformat() if o.created_at else None,
    }


@router.get("/orders")
def get_orders(
    status: Optional[str] = None,
    source: Optional[str] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    _user, e = auth
    q = db.query(Order).filter(
        Order.enterprise_id.isnot(None),
        Order.enterprise_id == e.id,
        Order.hidden_for_enterprise == False,  # noqa: E712
        Order.status.notin_(["COMPLETED", "DELIVERED", "CANCELLED"]),
    )
    if status:
        q = q.filter(Order.status == status)
    if source:
        q = q.filter(Order.source == source)
    orders = q.order_by(Order.created_at.desc()).offset(skip).limit(limit).all()
    return [_order_dict(o) for o in orders]


@router.get("/history")
def get_history(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    """Completed and cancelled orders (history)."""
    _user, e = auth
    orders = (db.query(Order)
              .filter(
                  Order.enterprise_id.isnot(None),
                  Order.enterprise_id == e.id,
                  Order.hidden_for_enterprise == False,  # noqa: E712
                  Order.status.in_(["COMPLETED", "DELIVERED", "CANCELLED"]),
              )
              .order_by(Order.created_at.desc())
              .offset(skip).limit(limit).all())
    return [_order_dict(o) for o in orders]


@router.delete("/history/{order_id}")
def delete_history_order(
    order_id: int,
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    """Soft-delete a single order from enterprise history."""
    _user, e = auth
    order = db.query(Order).filter(
        Order.id == order_id, Order.enterprise_id == e.id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Заказ табылган жок")
    order.hidden_for_enterprise = True
    db.commit()
    return {"message": "Заказ тарыхтан өчүрүлдү"}


@router.delete("/history")
def clear_history(
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    """Soft-delete all completed/cancelled orders from enterprise history."""
    _user, e = auth
    updated = (db.query(Order)
               .filter(
                   Order.enterprise_id == e.id,
                   Order.status.in_(["COMPLETED", "DELIVERED", "CANCELLED"]),
                   Order.hidden_for_enterprise == False,  # noqa: E712
               )
               .update({"hidden_for_enterprise": True}))
    db.commit()
    return {"message": f"{updated} заказ тарыхтан тазаланды"}


@router.post("/orders/create-local")
def create_local_order(
    data: LocalOrderCreate,
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    """Enterprise creates a local order: delivery or dine-in."""
    _user, enterprise = auth

    if data.order_type not in ("delivery", "dine_in"):
        raise HTTPException(status_code=400, detail="order_type: 'delivery' же 'dine_in' болушу керек")

    # --- Delivery: customer + address mildeettuu ---
    if data.order_type == "delivery":
        if not data.customer_phone:
            raise HTTPException(status_code=400, detail="Жеткирүү заказы үчүн кардардын телефону талап кылынат")
        if not data.to_address:
            raise HTTPException(status_code=400, detail="Жеткирүү дареги талап кылынат")
        customer = db.query(User).filter(User.phone == data.customer_phone).first()
        if not customer:
            raise HTTPException(
                status_code=404,
                detail=f"Колдонуучу {data.customer_phone} табылган жок. Алгач тиркемеде катталышы керек.")
        to_addr = data.to_address
        table_num = None
        order_source = "local"
    # --- Dine-in: стол номери гана ---
    else:
        to_addr = f"Стол №{data.table_number}" if data.table_number else (enterprise.address or enterprise.name)
        table_num = data.table_number
        order_source = "dine_in"
        # dine_in'де кардар камтылуучу (колдонуучу системасында болбосо ишкана аккаунту колдонулат)
        if data.customer_phone:
            customer = db.query(User).filter(User.phone == data.customer_phone).first()
            if not customer:
                raise HTTPException(
                    status_code=404,
                    detail=f"Колдонуучу {data.customer_phone} табылган жок.")
        else:
            # Ишкананын байланышкан колдонуучусун колдон
            customer = _user

    # Validate & collect items
    if not data.items:
        raise HTTPException(status_code=400, detail="Товар тандалган жок")

    total_price = Decimal("0")
    lines = []
    for item in data.items:
        if item.quantity <= 0:
            continue
        prod = db.query(EnterpriseProduct).filter(
            EnterpriseProduct.id == item.product_id,
            EnterpriseProduct.enterprise_id == enterprise.id,
            EnterpriseProduct.is_active == True,
        ).first()
        if not prod:
            raise HTTPException(status_code=400, detail=f"Товар #{item.product_id} табылган жок")
        line_total = Decimal(str(prod.price)) * item.quantity
        total_price += line_total
        lines.append(f"{prod.name} x{item.quantity} = {line_total:.0f} сом")

    description = "\n".join(lines)
    if data.note:
        description += f"\nЭскертүү: {data.note}"

    order = Order(
        user_id=customer.id,
        enterprise_id=enterprise.id,
        category=enterprise.category,
        description=description,
        from_address=enterprise.address or enterprise.name,
        to_address=to_addr,
        table_number=table_num,
        from_latitude=enterprise.lat,
        from_longitude=enterprise.lon,
        to_latitude=Decimal(str(data.to_lat)) if data.to_lat is not None else None,
        to_longitude=Decimal(str(data.to_lng)) if data.to_lng is not None else None,
        distance_km=Decimal("0"),
        price=total_price,
        items_total=total_price,
        # Local orders start as PREPARING; enterprise marks ready → WAITING_COURIER
        # Online orders (from mobile app) start as WAITING_COURIER directly
        status="PREPARING" if order_source == "local" else "WAITING_COURIER",
        source=order_source,
        order_type=data.order_type,
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return _order_dict(order)


# WAITING_COURIER = enterprise marks local order as ready → becomes visible to couriers
ALLOWED_DELIVERY_STATUSES = {"WAITING_COURIER", "ACCEPTED", "PREPARING", "READY", "CANCELLED"}
ALLOWED_DINE_IN_STATUSES = {"READY", "COMPLETED", "CANCELLED"}


@router.post("/orders/{order_id}/update-status")
def update_order_status(
    order_id: int,
    status: str,
    note: Optional[str] = None,
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    _user, enterprise = auth
    order = db.query(Order).filter(
        Order.id == order_id, Order.enterprise_id == enterprise.id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Заказ табылган жок")
    if order.status in ("COMPLETED", "DELIVERED"):
        raise HTTPException(status_code=400, detail="Бүтүп калган заказдын статусун өзгөртүүгө болбойт")

    allowed = ALLOWED_DINE_IN_STATUSES if order.order_type == "dine_in" else ALLOWED_DELIVERY_STATUSES
    if status not in allowed:
        raise HTTPException(status_code=400,
            detail=f"Жол берилген статустар: {sorted(allowed)}")

    order.status = status
    if note:
        order.admin_note = note
    db.commit()
    return {"message": "Статус жаңыланды", "status": status}


# ── Stats ─────────────────────────────────────────────────────────────────────

@router.get("/stats")
def get_stats(db: Session = Depends(get_db), auth: Tuple = Depends(require_enterprise)):
    _user, e = auth

    # Today's start in local time (matches SQLite func.now() storage)
    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)

    def _today_q():
        return db.query(Order).filter(
            Order.enterprise_id == e.id,
            Order.created_at >= today_start,
        )

    # Today's orders breakdown
    today_orders = _today_q().all()
    status_map: dict[str, int] = {}
    source_map: dict[str, int] = {}
    for o in today_orders:
        status_map[o.status] = status_map.get(o.status, 0) + 1
        source_map[o.source] = source_map.get(o.source, 0) + 1

    total = len(today_orders)
    pending = status_map.get("WAITING_COURIER", 0)
    active = sum(status_map.get(s, 0) for s in ("ACCEPTED", "READY", "IN_TRANSIT", "ON_THE_WAY", "PICKED_UP"))
    completed = sum(status_map.get(s, 0) for s in ("COMPLETED", "DELIVERED"))
    cancelled = status_map.get("CANCELLED", 0)

    completed_orders = [o for o in today_orders if o.status in ("COMPLETED", "DELIVERED")]
    local_revenue = sum(float(o.items_total or o.price) for o in completed_orders if o.source in ("local", "dine_in"))
    online_revenue = sum(float(o.items_total) for o in completed_orders if o.source == "online" and o.items_total is not None)
    revenue_q = local_revenue + online_revenue

    # Active orders list (ongoing, not filtered by date)
    active_orders = (db.query(Order)
                     .filter(Order.enterprise_id == e.id,
                             Order.status.in_(("WAITING_COURIER", "ACCEPTED", "READY")))
                     .order_by(Order.created_at.desc()).limit(10).all())

    # Products & categories counts (all time)
    products_count = db.query(func.count(EnterpriseProduct.id)).filter(
        EnterpriseProduct.enterprise_id == e.id).scalar() or 0
    categories_count = db.query(func.count(EnterpriseCategory.id)).filter(
        EnterpriseCategory.enterprise_id == e.id).scalar() or 0

    return {
        # Today's stats
        "total_orders": total,
        "pending_orders": pending,
        "active_orders": active,
        "completed_orders": completed,
        "cancelled_orders": cancelled,
        "total_revenue": revenue_q,
        # By source (today)
        "online_orders": source_map.get("online", 0),
        "local_orders": source_map.get("local", 0) + source_map.get("dine_in", 0),
        "online_revenue": online_revenue,
        "local_revenue": local_revenue,
        # Menu (all time)
        "products_count": products_count,
        "categories_count": categories_count,
        # Active orders list (ongoing)
        "active_orders_list": [_order_dict(o) for o in active_orders],
    }


# ── Reports ───────────────────────────────────────────────────────────────────

@router.get("/reports")
def get_reports(
    days: int = 1,
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    """Returns order/revenue report for last `days` days (1, 7, or 30)."""
    _user, e = auth
    if days not in (1, 7, 30):
        raise HTTPException(status_code=400, detail="days: 1, 7 же 30 болушу керек")

    # Calendar-day boundaries in local time (matches SQLite func.now() storage)
    today_local = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    since = today_local - timedelta(days=days - 1)  # days=1 → today 00:00, days=7 → 6 days ago 00:00

    base_q = db.query(Order).filter(
        Order.enterprise_id == e.id,
        Order.created_at >= since,
    )

    all_orders = base_q.all()
    completed = [o for o in all_orders if o.status in ("COMPLETED", "DELIVERED")]
    cancelled = [o for o in all_orders if o.status == "CANCELLED"]
    active = [o for o in all_orders if o.status not in ("COMPLETED", "DELIVERED", "CANCELLED")]

    local_revenue = sum(float(o.items_total or o.price) for o in completed if o.source in ("local", "dine_in"))
    online_revenue = sum(float(o.items_total) for o in completed if o.source == "online" and o.items_total is not None)
    total_revenue = local_revenue + online_revenue

    online_orders = [o for o in all_orders if o.source == "online"]
    local_orders = [o for o in all_orders if o.source in ("local", "dine_in")]
    dine_in_orders = [o for o in all_orders if o.source == "dine_in"]

    # Daily breakdown
    daily: dict[str, dict] = {}
    for i in range(days):
        d = (today_local - timedelta(days=days - 1 - i)).date()
        daily[str(d)] = {"date": str(d), "orders": 0, "revenue": 0.0, "cancelled": 0}

    for o in all_orders:
        d = str(o.created_at.date()) if o.created_at else None
        if d and d in daily:
            daily[d]["orders"] += 1
            if o.status in ("COMPLETED", "DELIVERED"):
                if o.source in ("local", "dine_in"):
                    daily[d]["revenue"] += float(o.items_total or o.price)
                elif o.source == "online" and o.items_total is not None:
                    daily[d]["revenue"] += float(o.items_total)
            if o.status == "CANCELLED":
                daily[d]["cancelled"] += 1

    return {
        "period_days": days,
        "total_orders": len(all_orders),
        "completed_orders": len(completed),
        "cancelled_orders": len(cancelled),
        "active_orders": len(active),
        "total_revenue": total_revenue,
        "online_orders": len(online_orders),
        "local_orders": len(local_orders) - len(dine_in_orders),
        "dine_in_orders": len(dine_in_orders),
        "online_revenue": online_revenue,
        "local_revenue": local_revenue,
        "daily": list(daily.values()),
    }

# ── Payment QR & Payments ─────────────────────────────────────────────────────

_ALLOWED_IMG = {"image/jpeg", "image/png", "image/webp", "image/gif", "image/heic", "image/heif"}
_EXT_MIME = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png",
             ".webp": "image/webp", ".gif": "image/gif", ".heic": "image/heic", ".heif": "image/heif"}


@router.post("/payment-qr")
async def upload_payment_qr(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    """Enterprise uploads their payment QR code image."""
    import os, base64
    _user, e = auth
    ext = os.path.splitext(file.filename or "")[1].lower() or ".jpg"
    mime = (file.content_type or "").lower()
    if mime not in _ALLOWED_IMG and ext not in _EXT_MIME:
        raise HTTPException(status_code=400, detail="Сүрөт файлы гана кабыл алынат")
    content = await file.read()
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Файл өтө чоң (макс 5МБ)")
    if mime not in _ALLOWED_IMG:
        mime = _EXT_MIME.get(ext, "image/jpeg")
    data_url = f"data:{mime};base64,{base64.b64encode(content).decode()}"
    e.payment_qr_url = data_url
    db.commit()
    return {"payment_qr_url": data_url}


@router.delete("/payment-qr")
def delete_payment_qr(
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    _user, e = auth
    e.payment_qr_url = None
    db.commit()
    return {"message": "QR код өчүрүлдү"}


class PaymentCreate(BaseModel):
    order_id: int
    amount: float
    screenshot_url: str


@router.post("/payments")
def create_payment(
    body: PaymentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """User submits payment screenshot for an enterprise order."""
    order = db.query(Order).filter(
        Order.id == body.order_id,
        Order.user_id == current_user.id,
        Order.enterprise_id.isnot(None),
    ).first()
    if not order:
        raise HTTPException(status_code=404, detail="Заказ табылган жок")

    existing = db.query(OrderPayment).filter(OrderPayment.order_id == body.order_id).first()
    if existing:
        existing.screenshot_url = body.screenshot_url
        existing.amount = body.amount
        existing.status = "pending"
        db.commit()
        db.refresh(existing)
        return _payment_dict(existing)

    payment = OrderPayment(
        order_id=body.order_id,
        enterprise_id=order.enterprise_id,
        user_id=current_user.id,
        amount=body.amount,
        screenshot_url=body.screenshot_url,
        status="pending",
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return _payment_dict(payment)


def _payment_dict(p: OrderPayment) -> dict:
    return {
        "id": p.id,
        "order_id": p.order_id,
        "amount": float(p.amount),
        "screenshot_url": p.screenshot_url,
        "status": p.status,
        "note": p.note,
        "user_phone": p.user.phone if p.user else None,
        "user_name": p.user.name if p.user else None,
        "created_at": p.created_at.isoformat() if p.created_at else None,
    }


@router.get("/payments")
def list_payments(
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    """Enterprise lists incoming payments."""
    _user, e = auth
    q = db.query(OrderPayment).filter(OrderPayment.enterprise_id == e.id)
    if status:
        q = q.filter(OrderPayment.status == status)
    payments = q.order_by(OrderPayment.created_at.desc()).limit(100).all()
    return [_payment_dict(p) for p in payments]


class PaymentAction(BaseModel):
    note: Optional[str] = None


@router.post("/payments/{payment_id}/confirm")
def confirm_payment(
    payment_id: int,
    body: PaymentAction = PaymentAction(),
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    _user, e = auth
    payment = db.query(OrderPayment).filter(
        OrderPayment.id == payment_id,
        OrderPayment.enterprise_id == e.id,
    ).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Төлөм табылган жок")
    payment.status = "confirmed"
    payment.note = body.note
    # Accept the order
    order = db.query(Order).filter(Order.id == payment.order_id).first()
    if order and order.status in ("WAITING_COURIER", "PREPARING"):
        order.status = "ACCEPTED"
    db.commit()
    return _payment_dict(payment)


@router.post("/payments/{payment_id}/reject")
def reject_payment(
    payment_id: int,
    body: PaymentAction = PaymentAction(),
    db: Session = Depends(get_db),
    auth: Tuple = Depends(require_enterprise),
):
    _user, e = auth
    payment = db.query(OrderPayment).filter(
        OrderPayment.id == payment_id,
        OrderPayment.enterprise_id == e.id,
    ).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Төлөм табылган жок")
    payment.status = "rejected"
    payment.note = body.note
    db.commit()
    return _payment_dict(payment)
