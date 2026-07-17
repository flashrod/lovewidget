#!/bin/bash
set -euo pipefail

SUPABASE_URL="https://xofjktwcynboblhcxchj.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhvZmprdHdjeW5ib2JsaGN4Y2hqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQyNzEwNDQsImV4cCI6MjA5OTg0NzA0NH0.4n7NA2DVltOp5HyEc-GjZPwWoIXb86xMDPCC5FLXpSw"

INVITE_CODE="${1:-}"
if [ -z "$INVITE_CODE" ]; then
    echo "Usage: $0 <INVITE-CODE>"
    echo "Get the code from the app's Pair tab -> Create"
    exit 1
fi

echo "=== Partner: Sign in anonymously ==="
RESP=$(curl -s -X POST "$SUPABASE_URL/auth/v1/signup" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{}')
TOKEN=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
USER_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['id'])")
echo "  Partner ID: $USER_ID"

echo ""
echo "=== Partner: Create user record ==="
curl -s -X POST "$SUPABASE_URL/rest/v1/users" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"id\": \"$USER_ID\", \"name\": \"Partner\", \"device_id\": \"partner-device-1\"}" | python3 -m json.tool 2>/dev/null

echo ""
echo "=== Partner: Join pair via RPC ==="
JOIN_RESP=$(curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/join_pair" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"p_invite_code\": \"$INVITE_CODE\", \"p_user_two_id\": \"$USER_ID\"}")
echo "$JOIN_RESP" | python3 -m json.tool 2>/dev/null
PAIR_ID=$(echo "$JOIN_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
echo "  Paired! Pair ID: $PAIR_ID"

echo ""
echo "=== Partner: Send drawing ==="
DRAWING='{"strokes":[{"id":"88888888-0000-0000-0000-000000000001","color":"crimson","width":4.0,"opacity":1.0,"points":[{"x":50,"y":50,"pressure":1},{"x":100,"y":150,"pressure":1},{"x":150,"y":80,"pressure":1},{"x":200,"y":200,"pressure":1}],"createdAt":"2026-07-17T08:35:00Z"},{"id":"88888888-0000-0000-0000-000000000002","color":"blue","width":2.0,"opacity":1.0,"points":[{"x":160,"y":40,"pressure":1},{"x":250,"y":120,"pressure":1}],"createdAt":"2026-07-17T08:35:01Z"}],"version":1,"createdAt":"2026-07-17T08:35:00Z","updatedAt":"2026-07-17T08:35:01Z"}'

curl -s -X POST "$SUPABASE_URL/rest/v1/drawings" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d "{\"pair_id\": \"$PAIR_ID\", \"drawing_json\": $DRAWING, \"created_by\": \"$USER_ID\"}"

echo "  Drawing sent! Check the app - it should appear via realtime."

echo ""
echo "=== Done ==="