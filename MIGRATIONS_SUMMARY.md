# Database Migrations Summary

## Current State ✅

The Batjetkiret backend now uses **Alembic** for managing database schema changes safely and consistently across environments.

### What's Been Done

1. **Alembic Framework Initialized**
   - Migration directory structure created
   - Environment configuration set up
   - Connected to your PostgreSQL database

2. **First Migration Created**
   - Revision: `90d719f958fb`
   - Changes: Added `type` and `admin_id` columns to `chat_rooms` table
   - Status: Applied and stamped to current database
   - File: [alembic/versions/90d719f958fb_add_type_and_admin_id_columns_to_chat_.py](alembic/versions/90d719f958fb_add_type_and_admin_id_columns_to_chat_.py)

3. **Database Initialization Script Created**
   - File: [init_database.py](init_database.py)
   - Purpose: Sets up fresh databases with proper migration tracking
   - Usage: `python init_database.py`

4. **Comprehensive Guides Created**
   - [MIGRATIONS.md](MIGRATIONS.md) - Developer guide for working with migrations
   - [DEPLOYMENT.md](DEPLOYMENT.md) - Production deployment procedures
   - This file for overview

## Quick Reference

### For Developers

**Making schema changes:**
```bash
# 1. Update your models in app/models/
# 2. Generate migration
alembic revision --autogenerate -m "Description of change"

# 3. Review generated file
# 4. Apply locally
alembic upgrade head

# 5. Test thoroughly
# 6. Commit migration file to git
```

**Checking status:**
```bash
# See current migration version
alembic current

# View migration history
alembic history

# See what would be applied
alembic upgrade --sql head
```

### For DevOps/SysAdmin

**Fresh database setup:**
```bash
# Initialize new database
python init_database.py

# Or use Alembic directly
createdb batjetkiret  # Create database
alembic upgrade head   # Apply migrations
```

**Production deployment:**
```bash
# Before deploying code with schema changes:
# 1. Backup database
pg_dump production_db > backup.sql

# 2. Apply migrations
alembic upgrade head

# 3. Verify
alembic current

# 4. Restart application
systemctl restart batjetkiret
```

**Rollback**:
```bash
# If something goes wrong
alembic downgrade -1  # Go back one version

# Or to specific version
alembic downgrade 90d719f958fb
```

## File Structure

```
batjetkiret-backend/
├── alembic/                          # Migration framework
│   ├── versions/                     # Migration files
│   │   └── 90d719f958fb_...py       # Current migration
│   ├── env.py                        # Migration environment
│   └── script.py.mako                # Migration template
├── alembic.ini                       # Alembic configuration
├── init_database.py                  # Fresh DB initialization
├── MIGRATIONS.md                     # Developer migration guide
├── DEPLOYMENT.md                     # Production deployment guide
└── app/
    └── models/                       # SQLAlchemy models
```

## Key Concepts

### Database Versioning

Each migration has a unique revision ID (hash) that tracks database state:
- `90d719f958fb` = Current production version
- Migrations are applied sequentially in order
- Can rollback to any previous version

### Two Approaches to Schema Management

**1. Fresh Database Setup** (New environments)
```bash
python init_database.py
# Creates tables + migration tracking automatically
```

**2. Migrations First** (Existing databases)
```bash
alembic upgrade head
# Applies only pending schema changes
```

### Production Safety

✅ **Advantages of Alembic:**
- Version control for schema changes
- Deterministic deployment (same result everywhere)
- Rollback capability if issues occur
- Audit trail of all changes
- No manual ALTER TABLEs needed
- Easy to track who changed what and when

## Current Migration Explained

**Migration ID:** `90d719f958fb`

**Purpose:** Add support for different chat room types (ORDER vs SUPPORT) and admin assignment

**What it does:**

```sql
-- Add type column
ALTER TABLE chat_rooms 
ADD COLUMN type VARCHAR NOT NULL DEFAULT 'ORDER';

-- Add admin_id column for support chat assignment  
ALTER TABLE chat_rooms 
ADD COLUMN admin_id INTEGER;
```

**Why it exists:**
- Original design didn't distinguish between order chats and support chats
- System needed ability to assign support chats to specific admins
- This migration formalizes that schema requirement

**Applied automatically:** Yes (stamped as already applied)

## Next Steps After This

1. **For Development:**
   - When you update models, Alembic generates migrations automatically
   - Review migrations before committing to git
   - Test on staging before production

2. **For Deployment:**
   - Follow [DEPLOYMENT.md](DEPLOYMENT.md) procedures
   - Always backup before applying migrations
   - Monitor application after deployment

3. **For Maintenance:**
   - Keep backup of migration files (they're version controlled)
   - Document unusual data transformations
   - Use recorded migrations for audit trails

## Environment Setup

### Configuration

Alembic reads from two sources (in order):
1. `DATABASE_URL` environment variable (preferred)
2. `sqlalchemy.url` setting in `alembic.ini`

Both need to point to your database:
```
postgresql://username:password@host:port/database
```

### Testing Different Environments

```bash
# Local development
DATABASE_URL="postgresql://localhost/batjetkiret_dev" alembic current

# Staging
DATABASE_URL="postgresql://staging-host/batjetkiret_staging" alembic current

# Production
DATABASE_URL="postgresql://prod-host/batjetkiret" alembic current
```

## Common Tasks

| Task | Command |
|------|---------|
| Check migration history | `alembic history` |
| See current version | `alembic current` |
| See pending changes | `alembic upgrade --sql head` |
| Create new migration | `alembic revision --autogenerate -m "description"` |
| Apply all pending | `alembic upgrade head` |
| Rollback one version | `alembic downgrade -1` |
| Rollback specific version | `alembic downgrade 90d719f958fb` |
| Init fresh database | `python init_database.py` |

## Troubleshooting

### Issue: `alembic: command not found`

**Solution:** Use full path from venv
```bash
./venv/bin/alembic current
# Instead of just: alembic current
```

### Issue: "Target database is not up to date"

**This is normal!** It means:
- Your database is already at the latest migration
- No new changes to apply
- Safe to proceed with deployment

### Issue: Migration won't apply / "Column already exists"

**Solution:**
1. Check current database version: `alembic current`
2. Verify database state: `psql -c "\d table_name"`
3. If mismatch, check migration file for errors
4. Last resort: Manually fix database and stamp version

See [MIGRATIONS.md](MIGRATIONS.md) troubleshooting section for more.

## Additional Resources

- **[MIGRATIONS.md](MIGRATIONS.md)** - Complete developer migration guide
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete production deployment guide
- **[Alembic Docs](https://alembic.sqlalchemy.org/)** - Official documentation
- **[PostgreSQL Docs](https://www.postgresql.org/docs/)** - Database documentation

---

## Summary

✅ **Alembic is now set up and operational**
- Migrations are tracked and version-controlled
- Database state is reproducible
- Safe deployment procedures established
- Rollback capability available
- Comprehensive documentation provided

**You can now:**
- Make schema changes safely and consistently
- Deploy to production with confidence
- Track all database changes in version control
- Rollback if needed
- Maintain clear audit trail

**Next:** For any schema changes, see [MIGRATIONS.md](MIGRATIONS.md) for step-by-step guide.

---

**Last Updated:** 2026-03-03  
**Alembic Version:** 1.18.1  
**Current Migration:** 90d719f958fb  
**Status:** ✅ Production Ready
