#!/usr/bin/env python3
"""
Test API endpoints with actual HTTP requests
"""

import sys
sys.path.insert(0, '/Users/nurgazyuson/python_projects/batjetkiret-backend')

import json
from app.core.database import SessionLocal
from app.models.user import User
import requests

def test_with_actual_api():
    """Test with real HTTP requests"""
    db = SessionLocal()
    try:
        # Get a test token (we'll simulate being user)
        user = db.query(User).filter(User.name == "Нургазы").first()
        
        if not user:
            print("User not found")
            return
        
        print(f"Testing as user: {user.name} (ID: {user.id})")
        print("\nMaking requests to API...\n")
        
        BASE_URL = "http://localhost:8001"
        
        # Test 1: Get orders
        print("1. GET /orders/my")
        response = requests.get(
            f"{BASE_URL}/orders/my",
            headers={"Authorization": f"Bearer test_token"}
        )
        print(f"   Status: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   Response count: {len(data) if isinstance(data, list) else 'not a list'}")
            for order in data[:1]:  # Show first order only
                print(f"   Order {order.get('id')}:")
                print(f"     - status: {order.get('status')}")
                print(f"     - courier: {order.get('courier')}")
        else:
            print(f"   Error: {response.text}")
        
    finally:
        db.close()

if __name__ == '__main__':
    try:
        test_with_actual_api()
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
