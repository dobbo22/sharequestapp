#!/usr/bin/env bash
set -euo pipefail

HOST=${1:-http://localhost:3000}
API="$HOST/api/items"

echo "Using API host: $API"

# Create a new item
echo "Creating item..."
CREATE_RESP=$(curl -sS -X POST "$API" -H "Content-Type: application/json" -d '{"title":"Test Item from script","details":"created by test script","isCompleted":false,"priority":1}')

echo "Create response: $CREATE_RESP"

# Try to parse id (works if id returned)
ID=$(echo "$CREATE_RESP" | sed -n 's/.*"id"[: "]\?\([0-9a-fA-F-]\+\)"?.*/\1/p')

if [ -z "$ID" ]; then
  # Attempt alternative: JSON parsing with node if available
  if command -v node >/dev/null 2>&1; then
    ID=$(node -e "const r=JSON.parse(process.argv[1]); console.log(r.id||r[0]?.id||'')" "$CREATE_RESP")
  fi
fi

if [ -n "$ID" ]; then
  echo "Created ID: $ID"
  echo "Fetching created item..."
  curl -sS "$API/$ID" | jq . || echo
else
  echo "No id found in create response; listing items instead."
  curl -sS "$API" | jq . || echo
fi

echo "Done."
