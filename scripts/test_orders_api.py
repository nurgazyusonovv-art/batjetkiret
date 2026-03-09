#!/usr/bin/env python3
"""
Script to test orders API response
"""

import sys
sys.path.insert(0, '/Users/nurgazyuson/python_projects/batjetkiret-backend')

import json
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.user import User
from app.models.order import Order

def test_api_response():
    """Test what API returns for orders"""
    db = SessionLocal()
    try:
        # Get all users and their orders
        users = db.query(User).all()
        
        print(f"Found {len(users)} users\n")
        
        for user in users:
            print(f"=== User: {user.name} (ID: {user.id}, courier={user.is_courier}) ===")
            
            orders = (
                db.query(Order)
                .filter(Order.user_id == user.id if not user.is_courier else Order.courier_id == user.id)
                .all()
            )
            
            print(f"  Orders: {len(orders)}")
            
            for o in orders:
                print(f"  - Order {o.id}: status={o.status}, courier_id={o.courier_id}, user_id={o.user_id}")
                
                # Simulate API response
                order_dict = {"id": o.id, "status": o.status}
                
                if not user.is_courier:
                    # User perspective - show courier
                    if o.courier_id:
                        order_dict["courier"] = {
                            "id": o.courier.id,
                            "name": o.courier.name,
                            "phone": o.courier.phone,
                        }
                        print(f"     → Courier: {order_dict['courier']['name']}")
                else:
                    # Courier perspective - show user
                    order_dict["user"] = {
                        "id": o.user.id,
                        "name": o.user.name,
                        "phone": o.user.phone,
                    }
                    print(f"     → User: {order_dict['user']['name']}")
            
            print()
        
    finally:
        db.close()

if __name__ == '__main__':
    test_api_response()
