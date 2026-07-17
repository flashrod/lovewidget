#!/bin/bash
# ============================================================
# LoveWidget — Supabase Setup Script
# ============================================================
# Prerequisites:
#   1. Install Supabase CLI: brew install supabase/tap/supabase
#   2. Create a Supabase project: supabase projects create
#   3. Link this directory: supabase link --project-ref <ref>
#
# Usage:
#   chmod +x Scripts/setup_supabase.sh
#   ./Scripts/setup_supabase.sh
# ============================================================

set -euo pipefail

echo "🚀 LoveWidget — Supabase Setup"
echo "================================"

# 1. Check prerequisites
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install: brew install supabase/tap/supabase"
    exit 1
fi

# 2. Check for project link
if [ ! -f "supabase/config.toml" ]; then
    echo "📦 Initializing Supabase project…"
    supabase init
    echo "⚠️  Run 'supabase link --project-ref <ref>' to link your project."
    echo "   Then re-run this script to apply migrations."
    exit 0
fi

# 3. Apply migrations
echo "📦 Applying database migrations…"
for migration in LoveWidgetCore/Sources/LoveWidgetCore/Supabase/migrations/*.sql; do
    name=$(basename "$migration")
    echo "   ↳ $name"
    supabase db push --db-url "$(supabase status --output json | jq -r '.db.url')" < "$migration"
done

# 4. Verify
echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "   1. Copy Config.xcconfig.template → Config.xcconfig"
echo "   2. Fill in your Supabase URL and anon key from:"
echo "      https://supabase.com/dashboard/project/<ref>/settings/api"
echo "   3. Run: xcodegen generate"
echo "   4. Build and run LoveWidget"
