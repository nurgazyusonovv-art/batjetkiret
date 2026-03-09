#!/usr/bin/env python3
"""
Script to delete all orders and related data from the database
"""
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal, engine
from app.models.order import Order
from app.models.transaction import Transaction
from app.models.order_status_log import OrderStatusLog
from app.models.chat import ChatRoom
from app.models.message import Message

def clear_all_orders():
    """Delete all orders and related data from the database"""
    db = SessionLocal()
    try:
        # Count orders before deletion
        orders_count = db.query(Order).count()
        print(f"📊 Заказдар саны (алдында): {orders_count}")
        
        if orders_count == 0:
            print("✅ Заказдар жок.")
            return
        
        # Delete related records in correct order (foreign key dependencies)
        print("\n🗑️  Байланышкан маалыматтарды өчүүдө...")
        
        # 1. Delete messages first (depends on chat_rooms)
        messages_deleted = db.query(Message).delete(synchronize_session=False)
        print(f"  ✅ Чат-билдирүүлөр өчүрүлдү: {messages_deleted}")
        
        # 2. Delete chat rooms for orders
        chats_deleted = db.query(ChatRoom).delete(synchronize_session=False)
        print(f"  ✅ Чат-бөлмөлөр өчүрүлдү: {chats_deleted}")
        
        # 3. Delete order status logs
        logs_deleted = db.query(OrderStatusLog).delete(synchronize_session=False)
        print(f"  ✅ Заказ статус логдору өчүрүлдү: {logs_deleted}")
        
        # 4. Delete transactions
        transactions_deleted = db.query(Transaction).delete(synchronize_session=False)
        print(f"  ✅ Транзакциялар өчүрүлдү: {transactions_deleted}")
        
        # 5. Finally delete all orders
        db.query(Order).delete()
        db.commit()
        
        # Confirm deletion
        count_after = db.query(Order).count()
        print(f"\n📊 Заказдар саны (кийинде): {count_after}")
        print(f"\n✅ {orders_count} заказ жана байланышкан маалыматтар ӧчүрүлдү!")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Ката: {e}")
        sys.exit(1)
    finally:
        db.close()

if __name__ == "__main__":
    clear_all_orders()
