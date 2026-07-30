from datetime import datetime, timedelta
from decimal import Decimal

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, require_admin
from app.models.advertisement import Advertisement
from app.models.notification import Notification
from app.models.setting import Setting
from app.models.transaction import Transaction
from app.models.user import User
from app.services.media_upload import upload_image_file


router = APIRouter(tags=["Advertisements"])

ADVERTISEMENT_PRICE_KEY = "advertisement_price"
ADVERTISEMENT_DURATION_KEY = "advertisement_default_duration_days"


class AdvertisementCreate(BaseModel):
    title: str
    description: str
    category: str | None = None
    contact_phone: str | None = None
    image_url: str | None = None
    duration_days: int | None = None


class AdvertisementReject(BaseModel):
    reason: str = ""


def _setting(db: Session, key: str, default: str) -> str:
    row = db.query(Setting).filter(Setting.key == key).first()
    return row.value if row else default


def _advertisement_price(db: Session) -> Decimal:
    try:
        return Decimal(str(float(_setting(db, ADVERTISEMENT_PRICE_KEY, "50"))))
    except (ValueError, TypeError):
        return Decimal("50")


def _default_duration_days(db: Session) -> int:
    try:
        return max(1, min(90, int(float(_setting(db, ADVERTISEMENT_DURATION_KEY, "7")))))
    except (ValueError, TypeError):
        return 7


def _expire_old_ads(db: Session) -> None:
    now = datetime.utcnow()
    (
        db.query(Advertisement)
        .filter(
            Advertisement.status == "ACTIVE",
            Advertisement.expires_at.isnot(None),
            Advertisement.expires_at < now,
        )
        .update({"status": "EXPIRED"}, synchronize_session=False)
    )


def _serialize_ad(ad: Advertisement, owner: User | None = None) -> dict:
    return {
        "id": ad.id,
        "user_id": ad.user_id,
        "user_name": owner.name if owner else None,
        "title": ad.title,
        "description": ad.description,
        "category": ad.category,
        "contact_phone": ad.contact_phone,
        "image_url": ad.image_url,
        "status": ad.status,
        "duration_days": ad.duration_days,
        "fee_amount": float(ad.fee_amount or 0),
        "view_count": int(ad.view_count or 0),
        "rejection_reason": ad.rejection_reason,
        "created_at": ad.created_at,
        "approved_at": ad.approved_at,
        "starts_at": ad.starts_at,
        "expires_at": ad.expires_at,
    }


@router.get("/advertisements/settings")
def advertisement_public_settings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return {
        "price": float(_advertisement_price(db)),
        "default_duration_days": _default_duration_days(db),
        "current_balance": float(current_user.balance or 0),
    }


@router.post("/advertisements/upload-image")
async def upload_advertisement_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    uploaded = await upload_image_file(
        file=file,
        key_prefix=f"advertisements/{current_user.id}/{int(datetime.utcnow().timestamp())}",
        max_bytes=8 * 1024 * 1024,
    )
    return {"url": uploaded.url}


@router.get("/advertisements")
def list_active_advertisements(db: Session = Depends(get_db)):
    _expire_old_ads(db)
    ads = (
        db.query(Advertisement, User)
        .join(User, User.id == Advertisement.user_id)
        .filter(Advertisement.status == "ACTIVE")
        .order_by(Advertisement.approved_at.desc().nullslast(), Advertisement.created_at.desc())
        .limit(100)
        .all()
    )
    db.commit()
    return [_serialize_ad(ad, owner) for ad, owner in ads]


@router.get("/advertisements/my")
def my_advertisements(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _expire_old_ads(db)
    ads = (
        db.query(Advertisement)
        .filter(
            Advertisement.user_id == current_user.id,
            Advertisement.status != "DELETED",
        )
        .order_by(Advertisement.created_at.desc())
        .all()
    )
    db.commit()
    return [_serialize_ad(ad, current_user) for ad in ads]


@router.post("/advertisements")
def create_advertisement(
    body: AdvertisementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    title = body.title.strip()
    description = body.description.strip()
    if len(title) < 3:
        raise HTTPException(status_code=400, detail="Аталышы кеминде 3 белги болушу керек")
    if len(description) < 10:
        raise HTTPException(status_code=400, detail="Текст кеминде 10 белги болушу керек")

    duration_days = body.duration_days or _default_duration_days(db)
    duration_days = max(1, min(90, int(duration_days)))
    fee = _advertisement_price(db)

    user = (
        db.query(User)
        .filter(User.id == current_user.id)
        .with_for_update()
        .first()
    )
    if not user:
        raise HTTPException(status_code=401)
    if (user.balance or Decimal("0")) < fee:
        raise HTTPException(
            status_code=400,
            detail=f"Жарнама берүү үчүн балансыңызда {fee} сом болушу керек",
        )

    user.balance -= fee
    ad = Advertisement(
        user_id=user.id,
        title=title,
        description=description,
        category=(body.category or "").strip() or None,
        contact_phone=(body.contact_phone or user.phone or "").strip() or None,
        image_url=(body.image_url or "").strip() or None,
        status="PENDING",
        duration_days=duration_days,
        fee_amount=fee,
    )
    db.add(ad)
    db.flush()
    db.add(
        Transaction(
            user_id=user.id,
            amount=-fee,
            type="ADVERTISEMENT_FEE",
        )
    )

    admins = db.query(User).filter(User.is_admin == True).all()  # noqa: E712
    for admin in admins:
        db.add(
            Notification(
                user_id=admin.id,
                title="Жаңы жарнама",
                message=f"{user.name} жарнама текшерүүгө жөнөттү: {title}",
            )
        )

    db.commit()
    db.refresh(ad)
    return _serialize_ad(ad, user)


@router.post("/advertisements/{ad_id}/view")
def register_advertisement_view(
    ad_id: int,
    db: Session = Depends(get_db),
):
    ad = db.query(Advertisement).filter(Advertisement.id == ad_id).with_for_update().first()
    if not ad or ad.status != "ACTIVE":
        raise HTTPException(status_code=404, detail="Жарнама табылган жок")

    ad.view_count = (ad.view_count or 0) + 1
    db.commit()
    return {"view_count": int(ad.view_count or 0)}


@router.post("/advertisements/{ad_id}/stop")
def stop_my_advertisement(
    ad_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ad = (
        db.query(Advertisement)
        .filter(
            Advertisement.id == ad_id,
            Advertisement.user_id == current_user.id,
        )
        .with_for_update()
        .first()
    )
    if not ad:
        raise HTTPException(status_code=404, detail="Жарнама табылган жок")
    if ad.status == "DELETED":
        raise HTTPException(status_code=400, detail="Жарнама өчүрүлгөн")
    if ad.status != "ACTIVE":
        raise HTTPException(status_code=400, detail="Активдүү жарнаманы гана токтотсо болот")

    now = datetime.utcnow()
    ad.status = "STOPPED"
    ad.expires_at = now
    db.commit()
    return _serialize_ad(ad, current_user)


@router.delete("/advertisements/{ad_id}")
def delete_my_advertisement(
    ad_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ad = (
        db.query(Advertisement)
        .filter(
            Advertisement.id == ad_id,
            Advertisement.user_id == current_user.id,
        )
        .with_for_update()
        .first()
    )
    if not ad:
        raise HTTPException(status_code=404, detail="Жарнама табылган жок")
    if ad.status == "DELETED":
        return _serialize_ad(ad, current_user)

    user = db.query(User).filter(User.id == current_user.id).with_for_update().first()
    should_refund = ad.status == "PENDING" and ad.fee_amount and ad.fee_amount > 0
    if user and should_refund:
        user.balance += ad.fee_amount
        db.add(
            Transaction(
                user_id=user.id,
                amount=ad.fee_amount,
                type="ADVERTISEMENT_REFUND",
            )
        )

    ad.status = "DELETED"
    ad.expires_at = datetime.utcnow()
    db.commit()
    return _serialize_ad(ad, user or current_user)


@router.get("/admin/advertisements")
def admin_list_advertisements(
    status: str | None = None,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    _expire_old_ads(db)
    query = db.query(Advertisement, User).join(User, User.id == Advertisement.user_id)
    if status:
        query = query.filter(Advertisement.status == status.upper())
    ads = query.order_by(Advertisement.created_at.desc()).limit(200).all()
    db.commit()
    return [_serialize_ad(ad, owner) for ad, owner in ads]


@router.post("/admin/advertisements/{ad_id}/approve")
def admin_approve_advertisement(
    ad_id: int,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    ad = db.query(Advertisement).filter(Advertisement.id == ad_id).with_for_update().first()
    if not ad:
        raise HTTPException(status_code=404, detail="Жарнама табылган жок")
    if ad.status not in ("PENDING", "REJECTED", "EXPIRED"):
        raise HTTPException(status_code=400, detail="Бул жарнаманы жактырууга болбойт")

    now = datetime.utcnow()
    ad.status = "ACTIVE"
    ad.rejection_reason = None
    ad.approved_by_admin_id = admin.id
    ad.approved_at = now
    ad.starts_at = now
    ad.expires_at = now + timedelta(days=ad.duration_days)

    db.add(
        Notification(
            user_id=ad.user_id,
            title="Жарнама жактырылды",
            message=f"'{ad.title}' жарнамаңыз жарыяланды",
        )
    )
    db.commit()
    return _serialize_ad(ad)


@router.post("/admin/advertisements/{ad_id}/reject")
def admin_reject_advertisement(
    ad_id: int,
    body: AdvertisementReject,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    ad = db.query(Advertisement).filter(Advertisement.id == ad_id).with_for_update().first()
    if not ad:
        raise HTTPException(status_code=404, detail="Жарнама табылган жок")
    if ad.status == "REJECTED":
        return _serialize_ad(ad)
    if ad.status == "ACTIVE":
        raise HTTPException(status_code=400, detail="Активдүү жарнаманы reject кылууга болбойт")

    user = db.query(User).filter(User.id == ad.user_id).with_for_update().first()
    if user and ad.fee_amount and ad.fee_amount > 0:
        user.balance += ad.fee_amount
        db.add(
            Transaction(
                user_id=user.id,
                amount=ad.fee_amount,
                type="ADVERTISEMENT_REFUND",
            )
        )

    ad.status = "REJECTED"
    ad.rejection_reason = body.reason.strip() or "Админ тарабынан четке кагылды"
    ad.approved_by_admin_id = admin.id
    ad.approved_at = datetime.utcnow()
    db.add(
        Notification(
            user_id=ad.user_id,
            title="Жарнама четке кагылды",
            message=f"'{ad.title}' жарнамаңыз четке кагылды. Акча балансыңызга кайтарылды.",
        )
    )
    db.commit()
    return _serialize_ad(ad, user)
