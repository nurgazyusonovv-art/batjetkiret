#!/bin/bash
# Migration Helper Script
# 
# Usage: ./migrate.sh [command] [options]
# Commands:
#   status           - Show current migration version
#   history          - View all migration history
#   new <message>    - Create new migration
#   up               - Apply all pending migrations
#   down             - Rollback last migration
#   init             - Initialize fresh database
#   test             - Test migrations on fresh database (destroys test DB)
#
# Examples:
#   ./migrate.sh status
#   ./migrate.sh new "Add user_preferences table"
#   ./migrate.sh up
#   ./migrate.sh down

set -e

VENV="./venv/bin"
PYTHON="$VENV/python"
ALEMBIC="$VENV/alembic"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load .env if exists
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
fi

# Ensure DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
    echo -e "${RED}❌ ERROR: DATABASE_URL environment variable not set${NC}"
    echo "   Set it in .env file or export it: export DATABASE_URL='postgresql://...'"
    exit 1
fi

function print_status() {
    echo -e "${BLUE}▸${NC} $1"
}

function print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

function print_error() {
    echo -e "${RED}❌${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}⚠️ ${NC} $1"
}

function check_alembic() {
    if [ ! -f "$ALEMBIC" ]; then
        print_error "Alembic not found at $ALEMBIC"
        echo "   Install with: pip install alembic"
        exit 1
    fi
}

function check_venv() {
    if [ ! -d "venv" ]; then
        print_error "Virtual environment not found"
        echo "   Create with: python -m venv venv"
        exit 1
    fi
}

function cmd_status() {
    print_status "Checking migration status..."
    $ALEMBIC current || print_warning "Could not determine current version"
}

function cmd_history() {
    print_status "Migration history:"
    $ALEMBIC history
}

function cmd_new() {
    local message="$1"
    if [ -z "$message" ]; then
        print_error "No message provided"
        echo "   Usage: ./migrate.sh new 'Your description here'"
        exit 1
    fi
    print_status "Creating new migration: $message"
    $ALEMBIC revision --autogenerate -m "$message"
    print_success "Migration created"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Review the migration file in alembic/versions/"
    echo "   2. Test locally: ./migrate.sh up"
    echo "   3. Commit to git: git add alembic/versions/"
    echo "   4. Deploy to production with: ./migrate.sh up"
}

function cmd_up() {
    print_status "Checking pending migrations..."
    
    # Check what would be applied
    local pending=$($ALEMBIC upgrade --sql head 2>/dev/null | grep -c "^" || echo "0")
    
    if [ "$pending" -le 1 ]; then
        print_warning "No new migrations to apply"
        print_status "Database is up to date"
        return 0
    fi
    
    print_status "Applying migrations..."
    $ALEMBIC upgrade head || {
        print_error "Migration failed!"
        echo ""
        echo "Troubleshooting:"
        echo "  • Check error message above"
        echo "  • Verify DATABASE_URL is correct"
        echo "  • Ensure database is running"
        echo "  • Check migration file syntax"
        exit 1
    }
    print_success "Migrations applied"
    cmd_status
}

function cmd_down() {
    print_warning "Rolling back last migration..."
    read -p "Are you sure? (yes/no) " -n 3 -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Rollback cancelled"
        return 0
    fi
    
    $ALEMBIC downgrade -1 || {
        print_error "Rollback failed!"
        exit 1
    }
    print_success "Rolled back to previous version"
    cmd_status
}

function cmd_init() {
    print_status "Initializing fresh database..."
    $PYTHON init_database.py
    if [ $? -eq 0 ]; then
        print_success "Database initialized"
    else
        print_error "Database initialization failed"
        exit 1
    fi
}

function cmd_test() {
    print_warning "Testing migrations on fresh database"
    print_warning "This will destroy batjetkiret_test if it exists!"
    read -p "Continue? (yes/no) " -n 3 -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Test cancelled"
        return 0
    fi
    
    print_status "Creating test database..."
    dropdb --if-exists batjetkiret_test 2>/dev/null || true
    createdb batjetkiret_test || {
        print_error "Could not create test database"
        echo "   Make sure PostgreSQL is running and you have permissions"
        exit 1
    }
    
    print_status "Running migrations on test database..."
    TEST_DB_URL="postgresql://batuser:batpass@localhost:5432/batjetkiret_test"
    DATABASE_URL="$TEST_DB_URL" $ALEMBIC upgrade head || {
        print_error "Migration test failed!"
        dropdb batjetkiret_test
        exit 1
    }
    
    print_status "Verifying schema..."
    DATABASE_URL="$TEST_DB_URL" $ALEMBIC current
    
    print_status "Cleaning up..."
    dropdb batjetkiret_test
    
    print_success "Migration test passed!"
}

# Main
check_venv
check_alembic

case "${1:-status}" in
    status)
        cmd_status
        ;;
    history)
        cmd_history
        ;;
    new)
        cmd_new "$2"
        ;;
    up)
        cmd_up
        ;;
    down|downgrade)
        cmd_down
        ;;
    init)
        cmd_init
        ;;
    test|verify)
        cmd_test
        ;;
    *)
        echo "Migration Helper Script"
        echo ""
        echo "Usage: ./migrate.sh [command] [options]"
        echo ""
        echo "Commands:"
        echo "  status           Show current migration version"
        echo "  history          View all migration history"
        echo "  new <message>    Create new migration"
        echo "  up               Apply all pending migrations"
        echo "  down             Rollback last migration"
        echo "  init             Initialize fresh database"
        echo "  test             Test migrations on fresh database"
        echo ""
        echo "Examples:"
        echo "  ./migrate.sh status              # Check current version"
        echo "  ./migrate.sh up                  # Deploy pending changes"
        echo "  ./migrate.sh new 'Add field X'   # Create new migration"
        echo ""
        echo "For more info, see: MIGRATIONS.md"
        exit 0
        ;;
esac
