#!/usr/bin/env python3
"""
Testing if Order objects are being created correctly
"""

import sys
sys.path.insert(0, '/Users/nurgazyuson/python_projects/batjetkiret-backend')

import json
from app.core.database import SessionLocal
from app.models.order import Order

def test_order_objects():
    """Test that Order objects have correct data"""
    db = SessionLocal()
    try:
        orders = db.query(Order).filter(Order.id.in_([8, 9])).all()
        
        print(f"Found {len(orders)} test orders\n")
        
        for order in orders:
            print(f"Order {order.id}:")
            print(f"  User: {order.user.name} (ID: {order.user_id})")
            print(f"  Courier: {order.courier.name if order.courier_id else 'None'} (ID: {order.courier_id})")
            print(f"  Status: {order.status}")
            
            # Simulate what API returns for user
            user_view = {
                "id": order.id,
                "status": order.status,
            }
            if order.courier_id:
                user_view["courier"] = {
                    "id": order.courier.id,
                    "name": order.courier.name,
                    "phone": order.courier.phone,
                }
            print(f"  User sees: {json.dumps(user_view, ensure_ascii=False)}")
            
            # Simulate what API returns for courier
            courier_view = {
                "id": order.id,
                "status": order.status,
                "user": {
                    "id": order.user.id,
                    "name": order.user.name,
                    "phone": order.user.phone,
                }
            }
            print(f"  Courier sees: {json.dumps(courier_view, ensure_ascii=False)}")
            print()
        
    finally:
        db.close()

if __name__ == '__main__':
    test_order_objects()
