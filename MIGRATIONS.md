# Database Migrations Guide

This project uses **Alembic** for managing database schema changes in a version-controlled, production-safe manner.

## Overview

Alembic is a lightweight database migration tool for SQLAlchemy. It tracks all schema changes and allows you to:
- Apply changes to your database deterministically
- Rollback changes if needed
- Deploy to production with confidence
- Maintain schema history and versioning

## Directory Structure

```
alembic/
├── versions/                          # Migration files
│   └── 90d719f958fb_add_type_and_admin_id...py   # First migration
├── env.py                             # Migration environment configuration
├── script.py.mako                     # Template for new migrations
└── README                             # Alembic documentation
alembic.ini                            # Alembic configuration
```

## Quick Start

### Prerequisites
- Ensure `DATABASE_URL` environment variable is set (or update `alembic.ini`)
- PostgreSQL database must be running and accessible

```bash
# Set environment variable if not already in .env
export DATABASE_URL="postgresql://batuser:batpass@localhost:5432/batjetkiret"
```

### Creating a Fresh Database (2 steps)

Fresh database setup should follow this sequence for production safety:

#### Step 1: Initialize Database Schema
Create the initial database structure using all models:

```bash
python -c "from app.core.init_db import init_db; init_db()"
```

This creates all tables from the ORM models.

#### Step 2: Stamp Current Version
Mark the database as having all current migrations already applied:

```bash
alembic stamp head
```

This ensures future migrations only apply NEW changes, not the baseline.

### For Subsequent Schema Changes

After the initial setup, schema changes follow this workflow:

#### 1. Modify your SQLAlchemy models
Update `app/models/*.py` with new fields or relationships.

#### 2. Generate migration
```bash
alembic revision --autogenerate -m "Brief description of change"
```

This auto-generates a migration file based on model differences.

#### 3. Review the migration
Check `alembic/versions/` for the generated migration file:
- Verify it includes only the intended changes
- Add any custom SQL if needed (e.g., data transformations)
- Ensure up() and down() methods are correct

#### 4. Apply migration
```bash
alembic upgrade head
```

This applies the migration to your database.

#### 5. Test thoroughly
- Verify schema changes with `\d table_name` in psql
- Test application with new schema
- Ensure no errors occur

## Existing Migrations

### Migration: `90d719f958fb_add_type_and_admin_id_columns_to_chat_rooms`

**What it does:**
- Adds `type` column (VARCHAR, NOT NULL, DEFAULT 'ORDER') to `chat_rooms`
- Adds `admin_id` column (INTEGER, nullable) to `chat_rooms`

**Purpose:**
- `type` field distinguishes between ORDER and SUPPORT chat rooms
- `admin_id` field links support chats to admin users

**Status:** Applied (manual ALTER TABLEs converted to migration)

### Migration: `3f2a6c1b9d4e_production_indexes_and_status_guardrails`

**What it does:**
- Enforces `orders.status` as `NOT NULL` with default `WAITING_COURIER`
- Adds DB-level status check constraint for valid lifecycle values
- Adds composite indexes for production query patterns:
    - `(user_id, created_at)`
    - `(courier_id, created_at)`
    - `(status, created_at)`
    - `chat_rooms(order_id, type)`

**Purpose:**
- Prevent invalid status writes at DB layer
- Reduce latency for order list and courier list endpoints under load

**Status:** New head migration

## Environment Setup

The Alembic environment (`alembic/env.py`) is configured to:
1. Read `DATABASE_URL` from environment variables first
2. Fall back to `alembic.ini` configuration if not set
3. Use SQLAlchemy's `Base.metadata` for autogenerate support

This allows running migrations without modifying configuration files:

```bash
DATABASE_URL="postgresql://..." alembic upgrade head
```

## Production Deployment

### Safe Deployment Checklist

- [ ] All migrations tested on staging database copy
- [ ] Backup production database before applying
- [ ] Run migrations during low-traffic window
- [ ] Verify no application downtime needed
- [ ] Test rollback procedure
- [ ] Monitor application after deployment

### Step-by-step Production Deploy

```bash
# 1. Backup production database
pg_dump -U batuser -h localhost batjetkiret > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Verify pending migrations
DATABASE_URL="prod_db_url" alembic current
DATABASE_URL="prod_db_url" alembic upgrade --sql --head  # See SQL without executing

# 3. Apply migrations
DATABASE_URL="prod_db_url" alembic upgrade head

# 4. Verify head revision
DATABASE_URL="prod_db_url" alembic current

# 4. Verify migration applied
DATABASE_URL="prod_db_url" alembic current
```

### Rollback Procedure

If issues occur after applying a migration:

```bash
# Rollback to previous migration
DATABASE_URL="postgresql://..." alembic downgrade -1

# Or rollback to specific version
DATABASE_URL="postgresql://..." alembic downgrade 90d719f958fb
```

## Testing Migrations

### Test on Fresh Database

```bash
# 1. Create test database
createdb batjetkiret_test

# 2. Run migrations
DATABASE_URL="postgresql://batuser:batpass@localhost:5432/batjetkiret_test" alembic upgrade head

# 3. Verify schema
psql -U batuser batjetkiret_test -c "\d chat_rooms"

# 4. Clean up
dropdb batjetkiret_test
```

### Test Migration Idempotency

Running migrations multiple times should be safe:

```bash
# Apply migrations
alembic upgrade head

# Run again (should do nothing)
alembic upgrade head
# Output: "Target database is not up to date"
```

## Advanced Topics

### Custom Migrations

For complex changes that autogenerate cannot handle, edit the migration manually:

```python
# alembic/versions/xyz_custom_migration.py

def upgrade() -> None:
    # Custom SQL operations
    op.execute("""
        UPDATE chat_rooms 
        SET type = 'SUPPORT' 
        WHERE admin_id IS NOT NULL
    """)

def downgrade() -> None:
    # Reverse the operation
    pass
```

### Data Migrations

If you need to transform data during migrations:

```python
def upgrade() -> None:
    # Add new column
    op.add_column('table', sa.Column('new_field', sa.String()))
    
    # Populate with transformed data
    op.execute("""
        UPDATE table 
        SET new_field = some_transformation(old_field)
    """)
    
    # Drop old column if replacing
    op.drop_column('table', 'old_field')

def downgrade() -> None:
    # Reverse transformations
    pass
```

### Checking Pending Migrations

```bash
# See all pending migrations without applying
alembic upgrade --sql head

# See all applied migrations
alembic history

# See current database version
alembic current
```

## Troubleshooting

### "alembic_version table does not exist"

This happens when starting with a fresh database:

```bash
# Solution 1: Create all tables first
python -c "from app.core.init_db import init_db; init_db()"
alembic stamp head

# Solution 2: Let migration create from scratch (for greenfield projects)
alembic upgrade head  # Creates alembic_version table automatically
```

### Migration fails with "column already exists"

Usually means:
1. Development database has manual schema changes
2. Migration file is incorrect
3. Migration was partially applied

**Fix:**
```bash
# Check current version
alembic current

# Check what was applied
psql -c "SELECT * FROM alembic_version"

# If needed, manually fix the alembic_version table
DELETE FROM alembic_version;  # Only if necessary!
alembic stamp 90d719f958fb
```

### "Target database is not up to date"

This is expected when trying to upgrade an already-current database. It means no changes needed.

## Best Practices

1. **Always autogenerate, then review**: Don't write migrations from scratch
2. **One logical change per migration**: Makes rollbacks easier
3. **Test on fresh database first**: Catch idempotency issues early
4. **Include rollback method**: Ensure downgrade() mirrors upgrade()
5. **Use migrations only for schema**: Data transformations should be in code
6. **Version control**: Commit migration files to git
7. **Never modify applied migrations**: Create new migrations for changes
8. **Document complex migrations**: Add comments explaining "why" not just "what"

## References

- [Alembic Official Documentation](https://alembic.sqlalchemy.org/)
- [Alembic Operations Guide](https://alembic.sqlalchemy.org/en/latest/ops.html)
- [SQLAlchemy Column Types](https://docs.sqlalchemy.org/en/20/core/types.html)
