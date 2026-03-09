#!/usr/bin/env python3
"""
Script to create test orders
"""

import sys
sys.path.insert(0, '/Users/nurgazyuson/python_projects/batjetkiret-backend')

from datetime import datetime
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.user import User
from app.models.order import Order

def create_test_orders():
    """Create test orders for debugging"""
    db = SessionLocal()
    try:
        # Get users
        user1 = db.query(User).filter(User.name == "Нургазы").first()  # ID 1
        user2 = db.query(User).filter(User.name == "Test User").first()  # ID 2
        courier1 = db.query(User).filter(User.name == "Асан").first()  # ID 3
        courier2 = db.query(User).filter(User.name == "Courier Test").first()  # ID 4
        
        if not all([user1, user2, courier1, courier2]):
            print("❌ Not all users found")
            return
        
        # Create test orders
        orders_to_create = [
            # Active order for user1 with courier1
            Order(
                user_id=user1.id,
                courier_id=courier1.id,
                category="food",
                description="Тестовый заказ 1",
                from_address="Бишкек, пр. Дүйнөбилик 1",
                to_address="Бишкек, ул. Чуй 100",
                distance_km=2.5,
                price=150,
                status="IN_TRANSIT",
            ),
            # Active order for user2 with courier2
            Order(
                user_id=user2.id,
                courier_id=courier2.id,
                category="groceries",
                description="Тестовый заказ 2",
                from_address="Бишкек, ын. Кожоева 1",
                to_address="Бишкек, ул. Абдрахманова 50",
                distance_km=3.0,
                price=200,
                status="ACCEPTED",
            ),
            # Pending order (no courier yet)
            Order(
                user_id=user1.id,
                courier_id=None,
                category="pharmacy",
                description="Тестовый заказ 3",
                from_address="Бишкек, ул. Ленина 1",
                to_address="Бишкек, ул. Саркулова 20",
                distance_km=1.5,
                price=100,
                status="WAITING_COURIER",
            ),
        ]
        
        for order in orders_to_create:
            db.add(order)
        
        db.commit()
        
        print("✅ Created 3 test orders")
        
        # Verify
        for order in orders_to_create:
            user = db.query(User).filter(User.id == order.user_id).first()
            courier = db.query(User).filter(User.id == order.courier_id).first() if order.courier_id else None
            print(f"  Order {order.id}: {user.name} → {courier.name if courier else 'No courier'} ({order.status})")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == '__main__':
    create_test_orders()
