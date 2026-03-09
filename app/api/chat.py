from collections import defaultdict
from typing import Any

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_current_user
from app.core.config import settings
from app.core.database import SessionLocal
from app.models.chat import ChatRoom
from app.models.message import Message
from app.models.notification import Notification
from app.models.order import Order
from app.models.user import User

router = APIRouter(prefix="/chat", tags=["Chat"])


class ChatConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[int, set[WebSocket]] = defaultdict(set)

    async def connect(self, chat_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections[chat_id].add(websocket)

    def disconnect(self, chat_id: int, websocket: WebSocket) -> None:
        sockets = self._connections.get(chat_id)
        if not sockets:
            return
        sockets.discard(websocket)
        if not sockets:
            self._connections.pop(chat_id, None)

    async def broadcast(self, chat_id: int, payload: dict[str, Any]) -> None:
        sockets = self._connections.get(chat_id)
        if not sockets:
            return

        stale: list[WebSocket] = []
        for socket in list(sockets):
            try:
                await socket.send_json(payload)
            except Exception:
                stale.append(socket)

        for socket in stale:
            self.disconnect(chat_id, socket)


manager = ChatConnectionManager()


def _message_to_dict(message: Message) -> dict[str, Any]:
    return {
        "id": message.id,
        "sender_id": message.sender_id,
        "text": message.text,
        "created_at": message.created_at.isoformat() if message.created_at else None,
        "is_read": bool(message.is_read),
    }


def _is_allowed_participant(chat: ChatRoom, user: User) -> bool:
    allowed_ids = [chat.user_id, chat.courier_id, chat.admin_id]
    return user.id in allowed_ids or user.is_admin


def _get_user_from_token(db: Session, token: str | None) -> User:
    if token is None or token.strip() == "":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")

    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except JWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc

    user = db.query(User).filter(User.id == int(user_id)).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid user")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User is blocked")

    return user


def _mark_chat_messages_read(db: Session, chat: ChatRoom, reader_id: int) -> tuple[int, int | None]:
    updated_count = (
        db.query(Message)
        .filter(
            Message.chat_id == chat.id,
            Message.sender_id != reader_id,
            Message.is_read == False,  # noqa: E712
        )
        .update({"is_read": True}, synchronize_session=False)
    )
    db.commit()

    last_read = (
        db.query(Message)
        .filter(
            Message.chat_id == chat.id,
            Message.sender_id != reader_id,
            Message.is_read == True,  # noqa: E712
        )
        .order_by(Message.id.desc())
        .first()
    )
    return updated_count, (last_read.id if last_read else None)


def _create_notifications(db: Session, chat: ChatRoom, sender_id: int) -> None:
    recipients: list[int | None] = []

    if chat.type == "ORDER":
        recipients = [chat.user_id, chat.courier_id]
    elif chat.type == "SUPPORT":
        recipients = [chat.user_id]
        if chat.admin_id:
            recipients.append(chat.admin_id)

    for uid in recipients:
        if uid and uid != sender_id:
            db.add(
                Notification(
                    user_id=uid,
                    title="New message",
                    message="You have a new chat message",
                    related_chat_id=chat.id,
                )
            )


async def _broadcast_read_update(chat_id: int, reader_id: int, last_read_message_id: int | None) -> None:
    await manager.broadcast(
        chat_id,
        {
            "event": "read_update",
            "chat_id": chat_id,
            "reader_id": reader_id,
            "last_read_message_id": last_read_message_id,
        },
    )


@router.get("/order/{order_id}")
def get_order_chat(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if current_user.id not in [order.user_id, order.courier_id]:
        raise HTTPException(status_code=403, detail="Access denied")

    if order.courier_id is None:
        raise HTTPException(status_code=409, detail="Courier is not assigned yet")

    chat = (
        db.query(ChatRoom)
        .filter(ChatRoom.order_id == order.id, ChatRoom.type == "ORDER")
        .first()
    )
    if chat is None:
        chat = ChatRoom(
            type="ORDER",
            order_id=order.id,
            user_id=order.user_id,
            courier_id=order.courier_id,
        )
        db.add(chat)
        db.commit()
        db.refresh(chat)

    return {"chat_id": chat.id, "order_id": order.id}


@router.get("/order/{order_id}/unread-count")
def get_order_unread_count(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if current_user.id not in [order.user_id, order.courier_id]:
        raise HTTPException(status_code=403, detail="Access denied")

    chat = (
        db.query(ChatRoom)
        .filter(ChatRoom.order_id == order.id, ChatRoom.type == "ORDER")
        .first()
    )
    if chat is None:
        return {"unread_count": 0}

    unread_count = (
        db.query(Message)
        .filter(
            Message.chat_id == chat.id,
            Message.sender_id != current_user.id,
            Message.is_read == False,  # noqa: E712
        )
        .count()
    )

    return {"unread_count": unread_count}


@router.websocket("/ws/{chat_id}")
async def chat_socket(websocket: WebSocket, chat_id: int):
    db = SessionLocal()
    user: User | None = None

    try:
        token = websocket.query_params.get("token")
        user = _get_user_from_token(db, token)

        chat = db.query(ChatRoom).filter(ChatRoom.id == chat_id).first()
        if chat is None or not _is_allowed_participant(chat, user):
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        await manager.connect(chat_id, websocket)

        _, last_read_message_id = _mark_chat_messages_read(db, chat, user.id)
        await _broadcast_read_update(chat_id, user.id, last_read_message_id)

        while True:
            data = await websocket.receive_json()
            event = data.get("event")

            if event == "ping":
                await websocket.send_json({"event": "pong"})
                continue

            if event == "mark_read":
                _, last_read_message_id = _mark_chat_messages_read(db, chat, user.id)
                await _broadcast_read_update(chat_id, user.id, last_read_message_id)
                continue

            if event == "send_message":
                text = str(data.get("text", "")).strip()
                if not text:
                    continue

                message = Message(
                    chat_id=chat.id,
                    sender_id=user.id,
                    text=text,
                )
                db.add(message)

                _create_notifications(db, chat, user.id)

                if chat.type == "SUPPORT" and user.is_admin:
                    chat.admin_id = user.id

                db.commit()
                db.refresh(message)

                await manager.broadcast(
                    chat_id,
                    {
                        "event": "new_message",
                        "chat_id": chat_id,
                        "message": _message_to_dict(message),
                    },
                )
                continue

            await websocket.send_json({"event": "error", "message": "Unknown event"})

    except WebSocketDisconnect:
        pass
    except HTTPException:
        try:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        except Exception:
            pass
    finally:
        manager.disconnect(chat_id, websocket)
        db.close()


@router.post("/{chat_id}/send")
async def send_message(
    chat_id: int,
    text: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = db.query(ChatRoom).filter(ChatRoom.id == chat_id).first()
    if not chat:
        raise HTTPException(status_code=404)

    if not _is_allowed_participant(chat, current_user):
        raise HTTPException(status_code=403)

    payload_text = text.strip()
    if payload_text == "":
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    msg = Message(
        chat_id=chat.id,
        sender_id=current_user.id,
        text=payload_text,
    )
    db.add(msg)

    _create_notifications(db, chat, current_user.id)

    if chat.type == "SUPPORT" and current_user.is_admin:
        chat.admin_id = current_user.id

    db.commit()
    db.refresh(msg)

    await manager.broadcast(
        chat_id,
        {
            "event": "new_message",
            "chat_id": chat_id,
            "message": _message_to_dict(msg),
        },
    )

    return {"message": "Sent"}


@router.get("/{chat_id}/messages")
def get_chat_messages(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = db.query(ChatRoom).filter(ChatRoom.id == chat_id).first()
    if not chat:
        raise HTTPException(status_code=404)

    if not _is_allowed_participant(chat, current_user):
        raise HTTPException(status_code=403)

    messages = (
        db.query(Message)
        .filter(Message.chat_id == chat.id)
        .order_by(Message.created_at)
        .all()
    )

    return [_message_to_dict(m) for m in messages]


@router.get("/{chat_id}/context")
def get_chat_context(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = db.query(ChatRoom).filter(ChatRoom.id == chat_id).first()
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")

    if not _is_allowed_participant(chat, current_user):
        raise HTTPException(status_code=403, detail="Access denied")

    counterparty_id: int | None = None
    if chat.type == "ORDER":
        if current_user.id == chat.user_id:
            counterparty_id = chat.courier_id
        elif current_user.id == chat.courier_id:
            counterparty_id = chat.user_id
    elif chat.type == "SUPPORT":
        if current_user.is_admin:
            counterparty_id = chat.user_id
        else:
            counterparty_id = chat.admin_id

    counterparty_name = None
    if counterparty_id is not None:
        counterparty = db.query(User).filter(User.id == counterparty_id).first()
        if counterparty is not None:
            counterparty_name = counterparty.name

    if chat.type == "SUPPORT" and counterparty_name is None:
        counterparty_name = "Колдоо кызматы"

    return {
        "chat_id": chat.id,
        "type": chat.type,
        "order_id": chat.order_id,
        "counterparty_id": counterparty_id,
        "counterparty_name": counterparty_name,
    }


@router.post("/{chat_id}/read-messages")
async def mark_read_by_chat_id(
    chat_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = db.query(ChatRoom).filter(ChatRoom.id == chat_id).first()
    if not chat:
        raise HTTPException(status_code=404)

    if not _is_allowed_participant(chat, current_user):
        raise HTTPException(status_code=403)

    _, last_read_message_id = _mark_chat_messages_read(db, chat, current_user.id)
    await _broadcast_read_update(chat.id, current_user.id, last_read_message_id)

    return {"message": "Messages marked as read"}


@router.post("/{order_id}/read")
async def mark_read(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chat = (
        db.query(ChatRoom)
        .filter(ChatRoom.order_id == order_id, ChatRoom.type == "ORDER")
        .first()
    )
    if not chat:
        raise HTTPException(status_code=404)

    if not _is_allowed_participant(chat, current_user):
        raise HTTPException(status_code=403)

    _, last_read_message_id = _mark_chat_messages_read(db, chat, current_user.id)
    await _broadcast_read_update(chat.id, current_user.id, last_read_message_id)

    return {"message": "Messages marked as read"}
