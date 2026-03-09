from app.core.database import engine, Base 
from app.models.user import User
from app.models.order import Order
from app.models.transaction import Transaction
from app.models.topup import TopUpRequest
from app.models.notification import Notification
from app.models.chat import ChatRoom
from app.models.message import Message
from app.models.rating import CourierRating
from app.models.user_rating import UserRating
from app.models.password_reset import PasswordReset
from app.models.order_status_log import OrderStatusLog


def init_db():
    Base.metadata.create_all(bind=engine)

if __name__ == "__main__":
    init_db()
