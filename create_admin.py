"""
Run once to create an admin user in the database.
Usage:
  python create_admin.py
Or with custom credentials:
  ADMIN_PHONE=+996700000001 ADMIN_PASSWORD=MySecret python create_admin.py
"""
import os
import sys

# Allow running from project root
sys.path.insert(0, os.path.dirname(__file__))

from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models.user import User

PHONE = os.environ.get("ADMIN_PHONE", "+996700000000")
PASSWORD = os.environ.get("ADMIN_PASSWORD", "Admin@2024!")
NAME = os.environ.get("ADMIN_NAME", "Admin")

db = SessionLocal()
try:
    existing = db.query(User).filter(User.phone == PHONE).first()
    if existing:
        existing.is_admin = True
        existing.hashed_password = hash_password(PASSWORD)
        db.commit()
        print(f"[OK] Updated existing user '{PHONE}' — is_admin=True, password reset.")
    else:
        admin = User(
            phone=PHONE,
            name=NAME,
            hashed_password=hash_password(PASSWORD),
            is_admin=True,
            is_active=True,
        )
        db.add(admin)
        db.commit()
        print(f"[OK] Admin user created.")

    print(f"  Phone:    {PHONE}")
    print(f"  Password: {PASSWORD}")
finally:
    db.close()
