from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.api.deps import get_db, get_current_user
from app.models.notification import Notification
from app.models.user import User
from app.services import fcm as fcm_service
from sqlalchemy import func

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("/")
def my_notifications(
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notifs = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(limit)
        .offset(offset)
        .all()
    )

    return [
        {
            "id": n.id,
            "title": n.title,
            "message": n.message,
            "chat_id": n.related_chat_id,
            "order_id": n.order_id,
            "is_read": n.is_read,
            "created_at": n.created_at,
        }
        for n in notifs
    ]


@router.get("/for-order/{order_id}")
def notifications_for_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notifs = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.order_id == order_id,
        )
        .order_by(Notification.created_at.desc())
        .all()
    )
    return [
        {
            "id": n.id,
            "title": n.title,
            "message": n.message,
            "is_read": n.is_read,
            "created_at": n.created_at,
        }
        for n in notifs
    ]


@router.post("/{notif_id}/read")
def mark_read(
    notif_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notif = (
        db.query(Notification)
        .filter(
            Notification.id == notif_id,
            Notification.user_id == current_user.id,
        )
        .first()
    )
    if not notif:
        raise HTTPException(status_code=404)

    notif.is_read = True
    db.commit()

    return {"message": "Marked as read"}


@router.post("/mark-all-read")
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False,
    ).update({"is_read": True})
    db.commit()
    return {"message": "All marked as read"}


@router.delete("/{notif_id}")
def delete_notification(
    notif_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notif = (
        db.query(Notification)
        .filter(
            Notification.id == notif_id,
            Notification.user_id == current_user.id,
        )
        .first()
    )
    if not notif:
        raise HTTPException(status_code=404)
    db.delete(notif)
    db.commit()
    return {"ok": True}


@router.post("/support-message")
def send_support_message(
    title: str,
    message: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Allow authenticated users to send a support message visible to all admins."""
    admins = db.query(User).filter(User.is_admin == True).all()  # noqa: E712
    full_title = f"[{current_user.phone}] {title}"
    for admin in admins:
        db.add(
            Notification(
                user_id=admin.id,
                title=full_title,
                message=message,
            )
        )
        # FCM push to admin device
        if admin.fcm_token:
            fcm_service.send_push(
                token=admin.fcm_token,
                title=full_title,
                body=message,
                data={"type": "support_message"},
                channel_id="batken_messages",
                include_notification=False,
            )
    db.commit()
    return {"message": "Билдирүү жөнөтүлдү"}


@router.get("/unread-count")
def unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    count = (
        db.query(func.count(Notification.id))
        .filter(
            Notification.user_id == current_user.id,
            Notification.is_read == False,
        )
        .scalar()
    )

    return {"unread": count}
