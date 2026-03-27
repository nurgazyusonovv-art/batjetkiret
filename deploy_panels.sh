#!/bin/bash
# Deploy admin-panel and enterprise-panel to Vercel production.
# Run this after 'git push' when panel source files change.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building admin-panel ==="
cd "$SCRIPT_DIR/admin-panel"
npm run build
npx vercel --prod --yes

echo ""
echo "=== Building enterprise-panel ==="
cd "$SCRIPT_DIR/enterprise-panel"
npm run build
npx vercel --prod --yes

echo ""
echo "✓ Both panels deployed to Vercel."
