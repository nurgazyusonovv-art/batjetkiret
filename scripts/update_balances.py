#!/usr/bin/env python3
"""
Script to update all user balances to 1000
"""

import sys
sys.path.insert(0, '/Users/nurgazyuson/python_projects/batjetkiret-backend')

from sqlalchemy.orm import Session
from app.core.database import SessionLocal, engine
from app.models.user import User

def update_all_balances():
    """Update balance for all users to 1000"""
    db = SessionLocal()
    try:
        # Get all users
        users = db.query(User).all()
        
        if not users:
            print("❌ No users found in database")
            return
        
        print(f"Found {len(users)} users")
        print("Updating balances to 1000...\n")
        
        # Update each user's balance
        for user in users:
            old_balance = float(user.balance) if user.balance else 0
            user.balance = 1000
            print(f"✅ User {user.id} ({user.name}): {old_balance} → 1000")
        
        # Commit changes
        db.commit()
        
        print(f"\n✅ Successfully updated {len(users)} users")
        
        # Verify changes
        print("\nVerifying changes...")
        updated_users = db.query(User).all()
        for user in updated_users:
            print(f"   User {user.id} ({user.name}): balance = {user.balance}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == '__main__':
    update_all_balances()
