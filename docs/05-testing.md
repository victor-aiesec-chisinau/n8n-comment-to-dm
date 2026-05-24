# Testing Guide

How to test the Comment Auto-DM system without real Instagram or TikTok comments.

---

## Quick Local Test — Instagram

Use the test webhook URL (no need to activate the workflow):

```bash
curl -X POST "https://your-n8n.com/webhook-test/instagram" \
  -H "Content-Type: application/json" \
  -d '{
    "entry": [{
      "id": "YOUR_PAGE_ID",
      "time": 1748000000,
      "changes": [{
        "field": "comments",
        "value": {
          "from": {
            "id": "TEST_USER_ID_12345",
            "name": "Test User"
          },
          "message": "leadership",
          "id": "COMMENT_ID_TEST_001",
          "post_id": "POST_ID_TEST_001",
          "verb": "add",
          "created_time": 1748000000
        }
      }]
    }]
  }'
```

Expected response: `{"status":"ok"}`

Then check **n8n → Executions** for the workflow run.

---

## Quick Local Test — TikTok

```bash
curl -X POST "https://your-n8n.com/webhook-test/tiktok" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "video.comment.create",
    "create_time": 1748000000,
    "data": {
      "video_id": "TEST_VIDEO_123",
      "comment_id": "COMMENT_ID_TEST_002",
      "comment_content": "workshop",
      "user_openid": "TEST_USER_OPENID_456",
      "user_nickname": "TikTok Test User"
    }
  }'
```

---

## Test Script

Save this as `scripts/test-webhook.sh` and make it executable:

```bash
#!/usr/bin/env bash

# ============================================================
# test-webhook.sh — Simulate comment events for local testing
# Usage: ./scripts/test-webhook.sh [instagram|tiktok] [keyword]
# ============================================================

N8N_BASE_URL="${N8N_URL:-https://your-n8n.com}"
PLATFORM="${1:-instagram}"
KEYWORD="${2:-leadership}"

echo "🧪 Testing $PLATFORM webhook with keyword: '$KEYWORD'"

if [ "$PLATFORM" = "instagram" ]; then
  curl -s -X POST "${N8N_BASE_URL}/webhook-test/instagram" \
    -H "Content-Type: application/json" \
    -d "{
      \"entry\": [{
        \"id\": \"TEST_PAGE_ID\",
        \"time\": $(date +%s),
        \"changes\": [{
          \"field\": \"comments\",
          \"value\": {
            \"from\": { \"id\": \"TEST_USER_$(date +%s)\", \"name\": \"Test User\" },
            \"message\": \"${KEYWORD}\",
            \"id\": \"COMMENT_$(date +%s)\",
            \"post_id\": \"POST_TEST_001\",
            \"verb\": \"add\",
            \"created_time\": $(date +%s)
          }
        }]
      }]
    }" | python3 -m json.tool

elif [ "$PLATFORM" = "tiktok" ]; then
  curl -s -X POST "${N8N_BASE_URL}/webhook-test/tiktok" \
    -H "Content-Type: application/json" \
    -d "{
      \"event\": \"video.comment.create\",
      \"create_time\": $(date +%s),
      \"data\": {
        \"video_id\": \"TEST_VIDEO_001\",
        \"comment_id\": \"COMMENT_$(date +%s)\",
        \"comment_content\": \"${KEYWORD}\",
        \"user_openid\": \"USER_$(date +%s)\",
        \"user_nickname\": \"Test TikTok User\"
      }
    }" | python3 -m json.tool

else
  echo "❌ Unknown platform: $PLATFORM"
  echo "Usage: $0 [instagram|tiktok] [keyword]"
  exit 1
fi

echo ""
echo "✅ Request sent. Check n8n → Executions for the result."
```

Run it:
```bash
chmod +x scripts/test-webhook.sh

# Test Instagram with 'leadership' keyword
./scripts/test-webhook.sh instagram leadership

# Test TikTok with 'workshop' keyword
./scripts/test-webhook.sh tiktok workshop

# Test cooldown (run same command twice — second should be blocked)
./scripts/test-webhook.sh instagram leadership
./scripts/test-webhook.sh instagram leadership  # should trigger "Skip - In Cooldown"
```

---

## Meta Webhook Verification Test

Test that Meta's webhook challenge verification works:

```bash
curl -s "https://your-n8n.com/webhook-test/instagram?\
hub.mode=subscribe&\
hub.verify_token=YOUR_META_VERIFY_TOKEN&\
hub.challenge=test_challenge_12345"
```

Expected response: `test_challenge_12345`

If you get an empty response or error, check:
- The `META_VERIFY_TOKEN` env var matches what you sent
- The workflow's GET webhook is active
- The `Extract Challenge` Code node has no errors

---

## Checking Analytics

After running tests, view the stored analytics in n8n:

1. Open the Instagram workflow
2. Click **Update Analytics** node
3. Click **Execute Node** (using test data from a previous run)
4. In the Code node, temporarily add at the top:
   ```javascript
   const staticData = $getWorkflowStaticData('global');
   console.log('Analytics:', JSON.stringify(staticData.analytics, null, 2));
   console.log('DM History:', JSON.stringify(staticData.dmHistory, null, 2));
   console.log('Send Counts:', JSON.stringify(staticData.sendCounts, null, 2));
   ```
5. Check the **Browser Console** or n8n logs for the output

---

## End-to-End Test Checklist

Before going live, verify each step:

| Step | How to test | Expected result |
|---|---|---|
| Webhook URL is reachable | `curl -X POST https://your-n8n.com/webhook/instagram` | `{"status":"ok"}` |
| Meta verification works | GET request with hub.challenge | Returns the challenge value |
| Keyword matching works | POST with a matching comment | Workflow runs, keyword matched |
| Non-keyword comment ignored | POST with random text | Skip - No Keyword Match node reached |
| DM is sent | POST with matching keyword to a real user ID | Check Instagram DMs |
| Public reply is sent | POST with matching keyword | Check comment replies on the post |
| Cooldown works | POST same user + keyword twice | Second run hits Skip - In Cooldown |
| Expiry works | Set `expires_at` to past date | Rule is skipped |
| Max sends works | Set `max_dm_sends: 1`, run twice | Second run skips the rule |

---

## Debugging Common Issues

### DM not sent — check n8n execution log

1. Go to n8n → Executions → click the failed execution
2. Look at which node stopped the flow:
   - **Skip - Invalid Event**: webhook payload wasn't a comment event
   - **Skip - No Keyword Match**: no rule matched the comment text
   - **Skip - In Cooldown**: user already received DM within cooldown window
   - **Send Instagram DM** (error): API call failed — check error message

### API error from Instagram: `OAuthException`
```
{"error":{"message":"Invalid OAuth access token","type":"OAuthException","code":190}}
```
→ Regenerate your `INSTAGRAM_ACCESS_TOKEN`

### API error: `(#10) To use 'Page Public Content Access', your use of this endpoint must be reviewed...`
→ Submit your app for App Review

### Cooldown won't reset during testing

The cooldown is stored in n8n's Static Workflow Data. To reset it:

Add this temporary Code node and execute it once:
```javascript
const staticData = $getWorkflowStaticData('global');
staticData.dmHistory = {};
staticData.sendCounts = {};
return [{ json: { cleared: true } }];
```

Then remove the node.
