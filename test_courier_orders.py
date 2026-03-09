#!/usr/bin/env python3
import requests
import json

BASE_URL = 'http://localhost:8001'

# Get all users to find a courier
db_response = requests.get(f'{BASE_URL}/admin/users')
print(f"Getting users: {db_response.status_code}")

# Try to login as an existing courier
response = requests.post(f'{BASE_URL}/auth/login', json={
    'email': 'courier@test.com',
    'phone': '0556123456',
    'password': 'test123'
})

if response.status_code == 200:
    token = response.json().get('access_token')
    print(f"✅ Logged in as courier")
    
    # Get courier orders
    response = requests.get(
        f'{BASE_URL}/courier/orders/my',
        headers={'Authorization': f'Bearer {token}'}
    )
    
    if response.status_code == 200:
        orders = response.json()
        print(f"Got {len(orders)} courier orders")
        if orders:
            order = orders[0]
            print(f"\nFirst order ID: {order.get('id')}")
            print(f"Has 'courier' field: {'courier' in order}")
            if 'courier' in order:
                print(f"Courier data: {json.dumps(order['courier'], indent=2)}")
            else:
                print("❌ 'courier' field is MISSING!")
                print(f"Order keys: {list(order.keys())}")
            print(f"Has 'user' field: {'user' in order}")
            if 'user' in order:
                print(f"User data: {json.dumps(order['user'], indent=2)}")
    else:
        print(f"Error getting orders: {response.status_code}")
        print(response.json())
else:
    print(f"❌ Login failed: {response.status_code}")
    if response.status_code == 401:
        print("Authentication error - courier credentials invalid")
