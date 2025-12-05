#!/bin/bash

# Script to check chunks on the backend
# Usage: ./check-chunks.sh [sessionId]

BASE_URL="${BASE_URL:-http://localhost:3000}"
SESSION_ID="$1"

if [ -z "$SESSION_ID" ]; then
  echo "Checking all chunks..."
  echo "GET $BASE_URL/v1/debug/chunks"
  echo ""
  curl -s "$BASE_URL/v1/debug/chunks" | jq '.'
else
  echo "Checking chunks for session: $SESSION_ID"
  echo "GET $BASE_URL/v1/debug/session/$SESSION_ID/chunks"
  echo ""
  curl -s "$BASE_URL/v1/debug/session/$SESSION_ID/chunks" | jq '.'
fi

