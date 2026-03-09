"""Make user admin by phone number"""
import sys
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.user import User

def make_admin(phone: str):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.phone == phone).first()
        
        if not user:
            print(f"❌ Колдонуучу '{phone}' номери менен табылган жок!")
            return False
        
        print(f"📱 Колдонуучу табылды:")
        print(f"   ID: {user.id}")
        print(f"   Телефон: {user.phone}")
        print(f"   Аты: {user.name or 'Жок'}")
        print(f"   Учурдагы is_admin: {user.is_admin}")
        
        user.is_admin = True
        db.commit()
        
        print(f"\n✅ Колдонуучу '{phone}' АДМИН кылынды!")
        return True
        
    except Exception as e:
        print(f"❌ Ката: {e}")
        db.rollback()
        return False
    finally:
        db.close()

if __name__ == "__main__":
    phone = "+996990310893"
    make_admin(phone)
