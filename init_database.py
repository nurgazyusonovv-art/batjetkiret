#!/usr/bin/env python
"""
Database Initialization Script with Alembic Support

This script safely initializes a fresh database with all schema and applies migrations.

Usage:
    python init_database.py
    DATABASE_URL="postgresql://..." python init_database.py
"""

import os
import sys
from pathlib import Path

# Add project to path
sys.path.insert(0, str(Path(__file__).parent))

from app.core.database import engine, Base
from app.core.init_db import init_db as init_tables
from sqlalchemy import text


def check_database_exists() -> bool:
    """Check if database is accessible."""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
            return True
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False


def check_alembic_table_exists() -> bool:
    """Check if alembic_version table exists."""
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1 FROM alembic_version LIMIT 1"))
            return True
    except:
        return False


def init_database():
    """
    Initialize a fresh database with proper migration tracking.
    
    This is the recommended way to set up a new database environment:
    1. Creates all tables from SQLAlchemy models
    2. Stamps the database as current with Alembic
    3. This ensures future migrations only apply NEW schema changes
    """
    import subprocess
    
    print("🔧 Batjetkiret Database Initialization")
    print("=" * 50)
    
    # Step 1: Check database connection
    print("\n1️⃣  Checking database connection...")
    if not check_database_exists():
        print("   Please ensure PostgreSQL is running and DATABASE_URL is correct")
        return False
    print("   ✅ Database is accessible")
    
    # Step 2: Initialize tables if needed
    print("\n2️⃣  Creating database schema...")
    try:
        # Create all tables from SQLAlchemy models
        Base.metadata.create_all(engine)
        print("   ✅ Schema created/verified")
    except Exception as e:
        print(f"   ❌ Failed to create schema: {e}")
        return False
    
    # Step 3: Check if alembic is set up
    print("\n3️⃣  Initializing migration tracking...")
    if check_alembic_table_exists():
        print("   ℹ️  Alembic already initialized (alembic_version table exists)")
        
        # Check current version
        try:
            result = subprocess.run(
                ["alembic", "current"],
                capture_output=True,
                text=True,
                env={**os.environ, "DATABASE_URL": os.getenv("DATABASE_URL", "")}
            )
            if result.returncode == 0:
                current_version = result.stdout.strip()
                print(f"   📊 Current migration version: {current_version}")
        except Exception as e:
            print(f"   ⚠️  Could not check migration version: {e}")
    else:
        print("   Setting up Alembic migration tracking...")
        try:
            # Stamp current database as having all migrations applied
            result = subprocess.run(
                ["alembic", "stamp", "head"],
                capture_output=True,
                text=True,
                env={**os.environ, "DATABASE_URL": os.getenv("DATABASE_URL", "")}
            )
            if result.returncode == 0:
                print("   ✅ Migration tracking initialized (head commit stamped)")
            else:
                print(f"   ⚠️  Alembic stamp warning: {result.stderr}")
        except Exception as e:
            print(f"   ⚠️  Alembic not available: {e}")
            print("      Run: pip install alembic (if not installed)")
    
    # Step 4: Verify schema
    print("\n4️⃣  Verifying schema...")
    try:
        with engine.connect() as conn:
            # Check key tables exist
            tables = [
                "users", "orders", "chat_rooms", "transactions", 
                "topup_requests", "notifications", "order_status_logs"
            ]
            missing = []
            for table in tables:
                try:
                    conn.execute(text(f"SELECT 1 FROM {table} LIMIT 1"))
                except:
                    missing.append(table)
            
            if missing:
                print(f"   ⚠️  Missing tables: {', '.join(missing)}")
            else:
                print(f"   ✅ All core tables verified: {', '.join(tables[:3])}... ({len(tables)} total)")
    except Exception as e:
        print(f"   ⚠️  Could not verify schema: {e}")
    
    print("\n" + "=" * 50)
    print("✅ Database initialization complete!")
    print("\nNext steps:")
    print("  • Start the application: uvicorn app.main:app --reload")
    print("  • View migrations: alembic history")
    print("  • Check current version: alembic current")
    print("\nFor schema changes:")
    print("  • Modify models in app/models/")
    print("  • Generate migration: alembic revision --autogenerate -m 'Description'")
    print("  • Apply migration: alembic upgrade head")
    print("  • See MIGRATIONS.md for detailed guide")
    
    return True


if __name__ == "__main__":
    # Ensure DATABASE_URL is set from environment
    if not os.getenv("DATABASE_URL"):
        # Try to load from .env
        from dotenv import load_dotenv
        load_dotenv()
    
    success = init_database()
    sys.exit(0 if success else 1)
