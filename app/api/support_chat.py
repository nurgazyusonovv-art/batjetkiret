from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.models.chat import ChatRoom
from app.models.user import User

router = APIRouter(prefix="/support", tags=["Support Chat"])

@router.post("/start")
def start_support_chat(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Бир active support chat болсун
    existing = (
        db.query(ChatRoom)
        .filter(
            ChatRoom.type == "SUPPORT",
            ChatRoom.user_id == current_user.id,
        )
        .first()
    )
    if existing:
        return {"chat_id": existing.id}

    chat = ChatRoom(
        type="SUPPORT",
        user_id=current_user.id,
    )
    db.add(chat)
    db.commit()
    db.refresh(chat)

    return {"chat_id": chat.id}
