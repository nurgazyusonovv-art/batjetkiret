#!/usr/bin/env bash
set -euo pipefail

# Creates a compressed PostgreSQL backup.
# Usage:
#   DATABASE_URL=postgresql://... scripts/backup_database.sh
#   BACKUP_DIR=/path/to/backups scripts/backup_database.sh

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: DATABASE_URL is required" >&2
  exit 1
fi

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "ERROR: pg_dump is not installed" >&2
  exit 1
fi

BACKUP_DIR="${BACKUP_DIR:-backups}"
mkdir -p "$BACKUP_DIR"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_DIR/batjetkiret-$STAMP.dump"

pg_dump "$DATABASE_URL" \
  --format=custom \
  --no-owner \
  --no-acl \
  --file="$OUT"

echo "$OUT"
