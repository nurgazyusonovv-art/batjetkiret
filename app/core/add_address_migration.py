"""
Migration script to add address column to users table
Run this manually using: python -m app.core.add_address_migration
"""
from sqlalchemy import create_engine, text
from app.core.config import settings

def run_migration():
    engine = create_engine(settings.DATABASE_URL)
    
    with engine.begin() as conn:
        # Check if column exists
        result = conn.execute(text("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name='users' AND column_name='address'
        """))
        
        if result.fetchone() is None:
            # Add address column
            conn.execute(text("ALTER TABLE users ADD COLUMN address VARCHAR"))
            print("✅ Added address column to users table")
        else:
            print("ℹ️  Address column already exists")

if __name__ == "__main__":
    run_migration()
