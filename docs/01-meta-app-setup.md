# Instagram / Meta App Setup

This guide walks you through creating a Meta Developer App and connecting it to n8n so Instagram comment events trigger your workflow.

---

## Prerequisites

- An **Instagram Business or Creator account** (personal accounts are not supported by the API)
- A **Facebook Page** connected to your Instagram account
- A **Meta Developer account**: [developers.facebook.com](https://developers.facebook.com)
- Your n8n instance must be **publicly accessible** (a domain with HTTPS, not `localhost`)

---

## Step 1 — Create a Meta App

1. Go to [developers.facebook.com/apps](https://developers.facebook.com/apps)
2. Click **Create App**
3. Select **Business** as the app type
4. Fill in:
   - App name: `Comment Auto DM` (or anything you prefer)
   - App contact email: your email
5. Click **Create App**

---

## Step 2 — Add the Instagram Product

1. Inside your app dashboard, click **Add Product**
2. Find **Instagram** and click **Set Up**
3. Under Instagram → Settings, link your **Facebook Page**
4. Click **Generate Token** — you'll get a **Page Access Token**

> ⚠️ **Long-lived token**: The default token expires in ~60 days. Generate a long-lived token:
> ```
> GET https://graph.facebook.com/v21.0/oauth/access_token
>   ?grant_type=fb_exchange_token
>   &client_id={app-id}
>   &client_secret={app-secret}
>   &fb_exchange_token={short-lived-token}
> ```

5. Copy the token — this is your `INSTAGRAM_ACCESS_TOKEN`

---

## Step 3 — Get Your Instagram User ID

```bash
curl "https://graph.facebook.com/v21.0/me?fields=id,name&access_token=YOUR_ACCESS_TOKEN"
```

The `id` returned is your `INSTAGRAM_USER_ID` (used for sending DMs).

---

## Step 4 — Request Required Permissions

In your Meta App, go to **App Review → Permissions and Features** and request:

| Permission | Purpose |
|---|---|
| `instagram_basic` | Read your account info |
| `instagram_manage_comments` | Read comments + post replies |
| `instagram_manage_messages` | Send DMs via Instagram Messaging API |
| `pages_manage_metadata` | Manage webhook subscriptions |
| `pages_read_engagement` | Read page engagement data |

> 💡 For development/testing, you can use these permissions without App Review on test users added to your app. For production (real public accounts), you **must** submit for App Review.

---

## Step 5 — Configure the Webhook

1. In your Meta App, go to **Webhooks** (or Instagram → Webhooks)
2. Click **Add Callback URL**
3. Enter:
   - **Callback URL**: `https://your-n8n.com/webhook/instagram`
   - **Verify Token**: choose a secret string, e.g., `my_super_secret_verify_token`
4. Click **Verify and Save**
   - Meta will send a `GET` request to your webhook URL
   - n8n must have the Instagram workflow **active** to respond to it
5. After verification, subscribe to the **`comments`** field

> 📌 Your n8n webhook URL:
> - **Test mode**: `https://your-n8n.com/webhook-test/instagram`
> - **Active (production)**: `https://your-n8n.com/webhook/instagram`

---

## Step 6 — Set n8n Environment Variables

In n8n: **Settings → Environment Variables**, add:

| Variable | Value |
|---|---|
| `META_VERIFY_TOKEN` | The verify token you chose in Step 5 |
| `INSTAGRAM_ACCESS_TOKEN` | The Page Access Token from Step 2 |
| `INSTAGRAM_USER_ID` | Your Instagram User ID from Step 3 |
| `KEYWORD_RULES` | The JSON array from `config/rules.example.json` |

---

## Step 7 — Activate the Workflow

1. Open n8n → import `workflows/instagram-comment-to-dm.json`
2. Click the **Active** toggle (top right)
3. The workflow is now live

---

## Testing the Connection

Post a comment on one of your Instagram Reels/posts using a keyword from your rules. Check n8n → Executions to see if it triggered.

To test without Instagram, use the test webhook URL and simulate a comment:

```bash
curl -X POST https://your-n8n.com/webhook-test/instagram \
  -H "Content-Type: application/json" \
  -d '{
    "entry": [{
      "id": "PAGE_ID",
      "time": 1234567890,
      "changes": [{
        "field": "comments",
        "value": {
          "from": { "id": "TEST_USER_ID", "name": "Test User" },
          "message": "leadership",
          "id": "COMMENT_ID_123",
          "post_id": "POST_ID_456",
          "verb": "add",
          "created_time": 1234567890
        }
      }]
    }]
  }'
```

---

## Troubleshooting

| Issue | Solution |
|---|---|
| Webhook verification fails | Make sure the workflow is **Active** and the `META_VERIFY_TOKEN` matches |
| DMs not sending | Check `instagram_manage_messages` permission is approved |
| `OAuthException` errors | Regenerate or refresh your access token |
| Events not arriving | Check webhook subscription is active for `comments` field |
| Can't DM user | Instagram requires the user to have interacted within 24h window |

---

## Instagram DM API Limitations

Instagram's Messaging API has usage restrictions:

- **RESPONSE type**: You can send a message within **24 hours** of a user's comment (treated as a response)
- After 24 hours: you need a message tag (e.g., `CONFIRMED_EVENT_UPDATE`) for event reminders
- **Best practice**: Process comments quickly and always use `"messaging_type": "RESPONSE"` (already set in the workflow)

The workflow sends `"messaging_type": "RESPONSE"` by default, which covers the typical use case where your automation runs within minutes of the comment.
