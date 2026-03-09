#!/usr/bin/env python3
"""
Script to change admin password to a simple one
"""
from app.core.database import SessionLocal
from app.models.user import User
from app.core.security import hash_password

db = SessionLocal()

# Find admin user by phone
admin_phone = "+996990310893"
admin_user = db.query(User).filter(User.phone == admin_phone).first()

if admin_user:
    # Set new simple password
    new_password = "admin123"
    admin_user.hashed_password = hash_password(new_password)
    db.commit()
    print(f"✅ Admin password updated!")
    print(f"📱 Phone: {admin_user.phone}")
    print(f"🔑 New password: {new_password}")
else:
    print(f"❌ Admin user with phone {admin_phone} not found")
    # List all users
    all_users = db.query(User).all()
    print(f"\nAvailable users: {len(all_users)}")
    for user in all_users:
        print(f"  - {user.phone} (is_admin: {user.is_admin})")

db.close()
