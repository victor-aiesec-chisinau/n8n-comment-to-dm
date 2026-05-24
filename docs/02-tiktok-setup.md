# TikTok App Setup

This guide walks you through connecting TikTok to n8n for comment-triggered automation.

---

## ⚠️ TikTok API Limitations (Read First)

Unlike Instagram, **TikTok does not have a public DM API** available to developers.

| Feature | Status |
|---|---|
| Comment webhooks (new comment events) | ✅ Available (Business API) |
| Comment replies (public reply to comment) | ✅ Available |
| Direct Messages (DMs) | ❌ Restricted — partners only |
| Comment reading (polling) | ✅ Available |

**What this means for the workflow:**
- The TikTok workflow replies **publicly** to the comment with the event link
- The link appears as a comment reply visible to everyone
- There is no private DM option unless you are an approved TikTok Business API partner

**Workaround strategies:**
1. Use the public reply with a short URL (`bit.ly` or custom domain) to look cleaner
2. Apply for [TikTok Business API](https://developers.tiktok.com/products/business-api/) partner access for DM capabilities
3. Use Instagram as the primary DM platform and TikTok for public replies

---

## Prerequisites

- A **TikTok Business or Creator account**
- A [TikTok Developer Account](https://developers.tiktok.com) (free)
- Your n8n instance must be **publicly accessible** with HTTPS

---

## Step 1 — Create a TikTok Developer App

1. Go to [developers.tiktok.com](https://developers.tiktok.com)
2. Click **Manage Apps → Create App**
3. Fill in:
   - App name: `Comment Auto Reply`
   - Category: Business Tools
4. Submit the app (basic review takes 1-2 business days)

---

## Step 2 — Configure OAuth Scopes

Under your app's **Products → Login Kit**, request these scopes:

| Scope | Purpose |
|---|---|
| `user.info.basic` | Access user info |
| `video.list` | Read your video list |
| `video.comment.list` | Read comments on your videos |
| `video.comment.create` | Post comment replies |

---

## Step 3 — Get Your Access Token

TikTok uses OAuth 2.0. To get an access token:

1. In the TikTok Developer Console, go to **OAuth 2.0 → Authorization URL**
2. Authorize your own TikTok account
3. Exchange the auth code for an access token:

```bash
curl -X POST "https://open.tiktokapis.com/v2/oauth/token/" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_key=YOUR_CLIENT_KEY" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "code=AUTH_CODE" \
  -d "grant_type=authorization_code" \
  -d "redirect_uri=YOUR_REDIRECT_URI"
```

Response:
```json
{
  "access_token": "act.xxx...",
  "refresh_token": "rft.xxx...",
  "expires_in": 86400,
  "refresh_expires_in": 31536000
}
```

> ⚠️ **Token Refresh**: TikTok access tokens expire every **24 hours**. You'll need to refresh them using the `refresh_token`. Consider building a separate n8n workflow to auto-refresh tokens and store them as env vars.

---

## Step 4 — Configure Webhook (Optional)

If your TikTok app has webhook access:

1. In your TikTok Developer App → **Webhooks**
2. Add endpoint: `https://your-n8n.com/webhook/tiktok`
3. Subscribe to: `video.comment.create`

For apps without webhook access, use the **polling fallback** (see below).

---

## Step 5 — Set n8n Environment Variables

In n8n: **Settings → Environment Variables**, add:

| Variable | Value |
|---|---|
| `TIKTOK_ACCESS_TOKEN` | Your OAuth access token |
| `TIKTOK_CLIENT_KEY` | App client key (for token refresh) |
| `TIKTOK_CLIENT_SECRET` | App client secret (for token refresh) |
| `KEYWORD_RULES` | JSON rules array (shared with Instagram workflow) |

---

## Step 6 — Polling Fallback (No Webhook Access)

If you don't have TikTok webhook access, you can poll for new comments:

### Add a Schedule Trigger

In n8n, open `tiktok-comment-reply.json` workflow and add a **Schedule Trigger** node:
- **Interval**: Every 5 minutes
- **Cron**: `*/5 * * * *`

Then add a **Code** node to fetch recent comments from your video:

```javascript
// Fetch recent comments from a TikTok video
const videoId = process.env.TIKTOK_VIDEO_ID; // Set this env var per video

const response = await $http.get({
  url: `https://open.tiktokapis.com/v2/video/comment/list/?video_id=${videoId}&max_count=20`,
  headers: {
    Authorization: `Bearer ${process.env.TIKTOK_ACCESS_TOKEN}`
  }
});

const comments = response.data?.data?.comments || [];

// Return each comment as a separate item
return comments.map(c => ({
  json: {
    valid: true,
    platform: 'tiktok',
    commentId: c.id,
    commentText: c.text,
    userId: c.create_user?.open_id,
    userName: c.create_user?.display_name,
    videoId,
    timestamp: c.create_time
  }
}));
```

Connect this output to the **Valid Comment?** IF node to continue the existing workflow.

---

## Step 7 — Activate the Workflow

1. Import `workflows/tiktok-comment-reply.json` in n8n
2. Toggle **Active**
3. Test by commenting the keyword on one of your TikTok videos

---

## Testing the TikTok Webhook

```bash
curl -X POST https://your-n8n.com/webhook-test/tiktok \
  -H "Content-Type: application/json" \
  -d '{
    "event": "video.comment.create",
    "create_time": 1234567890,
    "data": {
      "video_id": "TEST_VIDEO_ID",
      "comment_id": "COMMENT_ID_123",
      "comment_content": "workshop",
      "user_openid": "TEST_USER_OPENID",
      "user_nickname": "Test User"
    }
  }'
```

---

## Troubleshooting

| Issue | Solution |
|---|---|
| `access_token_expired` | Refresh token using your refresh_token |
| `permission_denied` | Ensure `video.comment.create` scope is approved |
| Reply not showing | TikTok may have rate limits; check Developer Console logs |
| No webhook events | TikTok webhook access may require partner approval — use polling |

---

## Applying for DM Access

To get TikTok DM capabilities:

1. Visit [developers.tiktok.com/products/business-api/](https://developers.tiktok.com/products/business-api/)
2. Apply for **Business API** access
3. Describe your use case: "Event registration link distribution to users who comment specific keywords"
4. Timeline: review typically takes 2-4 weeks

Until then, the public comment reply strategy works effectively and can include clickable links.
