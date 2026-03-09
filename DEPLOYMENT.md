# Production Deployment Guide - Database Migrations

## Overview

This guide covers safely deploying **Alembic database migrations** to production environments using the Batjetkiret backend system.

## Key Points

✅ **All current schema changes are now tracked by Alembic**
- Manual ALTER TABLE commands converted to version-controlled migrations
- Database state is stamped and reproducible 
- Future changes can be deployed deterministically

🔄 **Two-step database initialization workflow**
1. Create schema from models: `python init_database.py`
2. Or apply migrations: `alembic upgrade head`

🛡️ **Safe deployment process**
- Test on staging first
- Rollback capability included  
- No data loss (reversible migrations)
- Zero-downtime deployments possible

✅ **Production logging and request tracing enabled**
- Structured JSON logs for API requests
- Automatic `X-Request-ID` response header for traceability
- Configurable via environment variables (`LOG_LEVEL`, `LOG_JSON`, `SERVICE_NAME`)

## Migration Files

### Current Head Migrations

#### `90d719f958fb`

**What changed:**
```sql
-- Add type column to chat_rooms (handles both ORDER and SUPPORT chats)
ALTER TABLE chat_rooms ADD COLUMN type VARCHAR NOT NULL DEFAULT 'ORDER';

-- Add admin_id column (for admin support chat assignment)
ALTER TABLE chat_rooms ADD COLUMN admin_id INTEGER NULL;
```

**Files involved:**
- [alembic/versions/90d719f958fb_add_type_and_admin_id_columns_to_chat_.py](alembic/versions/90d719f958fb_add_type_and_admin_id_columns_to_chat_.py)
- Migration is already applied and stamped in current database

#### `3f2a6c1b9d4e`

**What changed:**
```sql
-- Ensure valid and non-null order status
ALTER TABLE orders ALTER COLUMN status SET NOT NULL;
ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'WAITING_COURIER';
ALTER TABLE orders ADD CONSTRAINT ck_orders_status_valid
   CHECK (status IN ('WAITING_COURIER','ACCEPTED','ON_THE_WAY','DELIVERED','COMPLETED','CANCELLED'));

-- Performance indexes for high-traffic queries
CREATE INDEX ix_orders_user_id_created_at ON orders (user_id, created_at);
CREATE INDEX ix_orders_courier_id_created_at ON orders (courier_id, created_at);
CREATE INDEX ix_orders_status_created_at ON orders (status, created_at);
CREATE INDEX ix_chat_rooms_order_id_type ON chat_rooms (order_id, type);
```

**Files involved:**
- [alembic/versions/3f2a6c1b9d4e_production_indexes_and_status_guardrails.py](alembic/versions/3f2a6c1b9d4e_production_indexes_and_status_guardrails.py)

## Logging Configuration (Production)

Add these to your environment:

```bash
LOG_LEVEL=INFO
LOG_JSON=true
SERVICE_NAME=batjetkiret-backend
```

## Deployment Scenarios

### Scenario 1: Fresh Production Server

```bash
# 1. Clone/pull code
git clone <repo> /opt/batjetkiret-backend
cd /opt/batjetkiret-backend

# 2. Set environment
export DATABASE_URL="postgresql://batuser:batpass@prod-db.example.com:5432/batjetkiret"
export SECRET_KEY="<production-secret>"

# 3. Initialize database (creates schema + migration tracking)
./venv/bin/python init_database.py

# Output should show:
# ✅ Database initialization complete!
# ✅ All core tables verified

# 4. Start application
./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

**Result:** 
- All tables created
- Migrations table initialized
- Application ready to serve requests
- Future schema changes can be deployed via `alembic upgrade head`

### Scenario 2: Existing Database with Manual Schema

**Context:** You already have a database with manual changes (like the current development DB)

```bash
# 1. Export environment
export DATABASE_URL="postgresql://batuser:batpass@prod-db:5432/batjetkiret"

# 2. Check current migration state
./venv/bin/alembic current
# Output: "90d719f958fb (head)" - your database is current!

# 3. Verify no new migrations pending
./venv/bin/alembic upgrade --sql head
# Output: "Target database is not up to date" - means you're current

# 4. Start application - no schema changes needed
./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

**Result:**
- Existing database is used as-is
- Migration tracking active
- Ready for future updates

### Scenario 3: Rolling Out New Schema Changes

**Context:** Code was updated with new model fields, need to apply schema changes

```bash
# 1. Developers committed new model changes
git pull origin main

# 2. Generate migration automatically
./venv/bin/alembic revision --autogenerate -m "Add new field X to table Y"

# 3. Review generated migration file
cat alembic/versions/<new_revision>.py

# 4. Test migration on staging database
export DATABASE_URL="postgresql://batuser:batpass@staging-db:5432/batjetkiret_staging"
./venv/bin/alembic upgrade head

# 5. Once tested, deploy to production
export DATABASE_URL="postgresql://batuser:batpass@prod-db:5432/batjetkiret"

# 6. Backup production database (required!)
pg_dump -U batuser -h prod-db batjetkiret > backup_2026_03_03.sql

# 7. Apply migration to production
./venv/bin/alembic upgrade head
# Monitor for errors

# 8. Restart application
systemctl restart batjetkiret  # or your deployment method

# 9. Monitor application health
curl https://api.batjetkiret.kg/health
```

## Pre-Deployment Checklist

### 48 Hours Before

- [ ] Cold backup of production database created
- [ ] Staging database refreshed from production backup
- [ ] All migrations tested on staging
- [ ] Team reviewed migration changes

### Day of Deployment

- [ ] Maintenance window scheduled (if needed)
- [ ] Team on standby for monitoring
- [ ] Rollback plan documented
- [ ] Backup verification complete

### Deployment Steps

```bash
#!/bin/bash
# Deployment script example

set -e  # Exit on first error
LOG_FILE="/var/log/batjetkiret_deploy_$(date +%Y%m%d_%H%M%S).log"

echo "🚀 Starting Batjetkiret deployment..." | tee $LOG_FILE

# Environment setup
export DATABASE_URL="postgresql://batuser:batpass@prod-db:5432/batjetkiret"
cd /opt/batjetkiret-backend

# 1. Code deployment
echo "📦 Pulling latest code..." | tee -a $LOG_FILE
git pull origin main 2>&1 | tee -a $LOG_FILE

# 2. Dependencies
echo "📚 Installing dependencies..." | tee -a $LOG_FILE
./venv/bin/pip install -r requirements.txt 2>&1 | tee -a $LOG_FILE

# 3. Back up database
echo "💾 Backing up database..." | tee -a $LOG_FILE
pg_dump -U batuser -h prod-db batjetkiret > backups/db_$(date +%Y%m%d_%H%M%S).sql 2>&1 | tee -a $LOG_FILE

# 4. Run migrations
echo "🔄 Running migrations..." | tee -a $LOG_FILE
./venv/bin/alembic upgrade head 2>&1 | tee -a $LOG_FILE

# 5. Verify application
echo "✅ Restarting application..." | tee -a $LOG_FILE
systemctl restart batjetkiret 2>&1 | tee -a $LOG_FILE

# 6. Health check
echo "🏥 Running health checks..." | tee -a $LOG_FILE
sleep 5
if curl -f http://localhost:8000/health > /dev/null; then
    echo "✅ Health check passed!" | tee -a $LOG_FILE
else
    echo "❌ Health check failed - rolling back!" | tee -a $LOG_FILE
    exit 1
fi

echo "✅ Deployment complete!" | tee -a $LOG_FILE
```

### Post-Deployment Verification

```bash
# Check migration version
alembic current

# Check application logs
tail -f /var/log/batjetkiret/app.log

# Verify API is responding
curl https://api.batjetkiret.kg/health

# Check database for schema changes
psql -U batuser -h prod-db -d batjetkiret -c "\d chat_rooms"
```

## Rollback Procedure

### If Deployment Fails

```bash
# 1. Identify the issue from logs
tail -f application.log

# 2. Rollback to previous migration state
export DATABASE_URL="postgresql://production_url"
./venv/bin/alembic downgrade -1

# 3. Restart application
systemctl restart batjetkiret

# 4. Verify health
curl https://api.batjetkiret.kg/health

# 5. If still failing, restore database backup
psql -U batuser -h prod-db -d batjetkiret < backup_2026_03_03.sql
```

### Emergency Recovery

```bash
# Restore from backup (if migration caused data issues)
pg_restore -U batuser -h prod-db -d batjetkiret backup_2026_03_03.sql

# Verify database state
./venv/bin/alembic current
# Output should match backup timestamp

# Redeploy previous version of code
git checkout <previous-tag>
./venv/bin/pip install -r requirements.txt
systemctl restart batjetkiret
```

## Migration Monitoring

### Key Metrics to Monitor After Deployment

1. **Database Connections**
   ```bash
   psql -c "SELECT count(*) FROM pg_stat_activity"
   ```

2. **Query Performance**
   - Monitor slow log for new queries
   - Check if indexes are being used

3. **Application Errors**
   - Monitor error logs
   - Check API response times
   - Verify no migration-related errors

4. **Data Integrity**
   ```bash
   # Check for NULL values in NOT NULL columns
   SELECT COUNT(*) FROM chat_rooms WHERE type IS NULL;
   ```

## Common Issues & Solutions

### Issue: "Target database is not up to date"

**Cause:** Trying to upgrade when already current
**Solution:** This is expected, no action needed. Database is current.

```bash
./venv/bin/alembic current
# Shows: 90d719f958fb (head)
./venv/bin/alembic upgrade head
# Output: "Target database is not up to date"
```

### Issue: "Relation 'chat_rooms' does not exist"

**Cause:** Migration tried to run but table lacks a column
**Solution:** Manually verify schema or restore backup

```bash
# Check current table structure
psql -c "\d chat_rooms"

# If columns missing, recreate them manually
psql -c "ALTER TABLE chat_rooms ADD COLUMN type VARCHAR DEFAULT 'ORDER';"
```

### Issue: "Foreign key constraint violation"

**Cause:** Migration tried to add constraint but data violated it
**Solution:** Clean data before reapplying migration

```bash
# Find violating records
SELECT * FROM table WHERE referenced_id NOT IN (SELECT id FROM referenced_table);

# Delete or fix the records
DELETE FROM table WHERE referenced_id IS NULL;

# Rerun migration
./venv/bin/alembic upgrade head
```

## Scaling Considerations

### Large Databases (GB+)

For large production databases, long-running migrations can lock tables:

```bash
# Use PostgreSQL's concurrent index build (for future migrations)
# In migration file:
op.create_index('idx_name', 'table', ['column'], postgresql_concurrently=True)

# Or add CONCURRENTLY to manual SQL:
op.execute("CREATE INDEX CONCURRENTLY idx_name ON table(column)")
```

### High-Traffic Systems

For systems that can't tolerate downtime:

```bash
# 1. Add column as nullable first
# 2. Backfill data in background
# 3. Add constraint in separate step
# 4. Update application to use new column
# 5. Remove old column (optional)
```

## Documentation Links

- [Alembic Official Docs](https://alembic.sqlalchemy.org/)
- [MIGRATIONS.md](MIGRATIONS.md) - Developer guide
- [PostgreSQL Backup Guide](https://www.postgresql.org/docs/current/backup.html)
- [System Administration](https://www.postgresql.org/docs/current/admin.html)

## Support & Troubleshooting

For deployment issues:

1. Check [MIGRATIONS.md](MIGRATIONS.md) for general migration questions
2. Review logs: `tail -f /var/log/batjetkiret/*.log`
3. Run health check: `curl http://localhost:8000/health`
4. Verify schema: `psql -c "\d"`
5. Check migration state: `./venv/bin/alembic current`

## Success Criteria

✅ Deployment is successful when:

- [ ] `alembic current` shows correct version
- [ ] Application starts without errors
- [ ] `/health` endpoint returns 200 OK
- [ ] Database queries work normally
- [ ] No error messages in logs
- [ ] Monitoring shows normal metrics

---

**Last Updated:** 2026-03-03  
**Migration Version:** 90d719f958fb  
**Database Type:** PostgreSQL 12+  
**Framework:** FastAPI + SQLAlchemy + Alembic
