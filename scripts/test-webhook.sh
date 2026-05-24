#!/usr/bin/env bash
# ============================================================
# test-webhook.sh — Simulate comment events for local testing
# Usage: ./scripts/test-webhook.sh [instagram|tiktok] [keyword]
# ============================================================

set -euo pipefail

N8N_BASE_URL="${N8N_URL:-https://your-n8n.com}"
PLATFORM="${1:-instagram}"
KEYWORD="${2:-leadership}"
USE_PRODUCTION="${3:-test}"  # 'test' uses webhook-test/, 'prod' uses webhook/

if [ "$USE_PRODUCTION" = "prod" ]; then
  WEBHOOK_PATH="webhook"
else
  WEBHOOK_PATH="webhook-test"
fi

echo ""
echo "======================================"
echo "  Comment Auto-DM Webhook Tester"
echo "======================================"
echo "  Platform  : $PLATFORM"
echo "  Keyword   : $KEYWORD"
echo "  n8n URL   : $N8N_BASE_URL/$WEBHOOK_PATH/$PLATFORM"
echo "======================================"
echo ""

TIMESTAMP=$(date +%s)
UNIQUE_USER="TEST_USER_${TIMESTAMP}"
UNIQUE_COMMENT="COMMENT_${TIMESTAMP}"

if [ "$PLATFORM" = "instagram" ]; then

  echo "📤 Sending Instagram comment event..."
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${N8N_BASE_URL}/${WEBHOOK_PATH}/instagram" \
    -H "Content-Type: application/json" \
    -d "{
      \"entry\": [{
        \"id\": \"TEST_PAGE_ID_001\",
        \"time\": ${TIMESTAMP},
        \"changes\": [{
          \"field\": \"comments\",
          \"value\": {
            \"from\": {
              \"id\": \"${UNIQUE_USER}\",
              \"name\": \"Test User\"
            },
            \"message\": \"${KEYWORD}\",
            \"id\": \"${UNIQUE_COMMENT}\",
            \"post_id\": \"POST_TEST_001\",
            \"verb\": \"add\",
            \"created_time\": ${TIMESTAMP}
          }
        }]
      }]
    }")

elif [ "$PLATFORM" = "tiktok" ]; then

  echo "📤 Sending TikTok comment event..."
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${N8N_BASE_URL}/${WEBHOOK_PATH}/tiktok" \
    -H "Content-Type: application/json" \
    -d "{
      \"event\": \"video.comment.create\",
      \"create_time\": ${TIMESTAMP},
      \"data\": {
        \"video_id\": \"TEST_VIDEO_001\",
        \"comment_id\": \"${UNIQUE_COMMENT}\",
        \"comment_content\": \"${KEYWORD}\",
        \"user_openid\": \"${UNIQUE_USER}\",
        \"user_nickname\": \"TikTok Test User\"
      }
    }")

elif [ "$PLATFORM" = "verify" ]; then

  echo "📤 Testing Meta webhook verification (GET)..."
  VERIFY_TOKEN="${META_VERIFY_TOKEN:-your_verify_token_here}"
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    "${N8N_BASE_URL}/${WEBHOOK_PATH}/instagram?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=test_challenge_${TIMESTAMP}")
  echo "Response body (should be the challenge value):"
  echo "$RESPONSE"
  echo ""
  echo "✅ If the response above equals 'test_challenge_${TIMESTAMP}', verification is working."
  exit 0

else
  echo "❌ Unknown platform: $PLATFORM"
  echo ""
  echo "Usage: $0 [instagram|tiktok|verify] [keyword] [test|prod]"
  echo ""
  echo "Examples:"
  echo "  $0 instagram leadership"
  echo "  $0 tiktok workshop"
  echo "  $0 instagram erasmus prod    # hits production webhook"
  echo "  $0 verify                    # tests Meta challenge verification"
  exit 1
fi

HTTP_BODY=$(echo "$RESPONSE" | head -n 1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

echo "Response ($HTTP_CODE):"
echo "$HTTP_BODY" | python3 -m json.tool 2>/dev/null || echo "$HTTP_BODY"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Webhook received successfully (HTTP 200)"
  echo ""
  echo "📊 Check n8n → Executions to see the workflow run."
  echo "   Look for which node the execution stopped at:"
  echo "   • 'Update Analytics'      → DM/reply was sent ✅"
  echo "   • 'Skip - No Keyword Match' → keyword not in rules"
  echo "   • 'Skip - In Cooldown'    → user already received DM"
  echo "   • 'Skip - Invalid Event'  → payload parsing failed"
else
  echo "❌ Unexpected response code: $HTTP_CODE"
  echo "   Check that the n8n workflow is active and the webhook URL is correct."
fi
