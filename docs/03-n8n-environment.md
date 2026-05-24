# n8n Environment Setup

This guide covers configuring n8n to run the Comment Auto-DM workflows.

---

## Option A — n8n Cloud (Easiest)

1. Sign up at [n8n.io/cloud](https://n8n.io/cloud)
2. Your webhook URL: `https://[your-instance].app.n8n.cloud/webhook/instagram`
3. Go to **Settings → Environment Variables** to add credentials

---

## Option B — Self-Hosted with Docker (Recommended)

### docker-compose.yml

```yaml
version: '3.8'
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${N8N_HOST}/
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - GENERIC_TIMEZONE=Europe/Bucharest
      # App credentials (can also be set in n8n UI → Settings → Environment Variables)
      - META_VERIFY_TOKEN=${META_VERIFY_TOKEN}
      - INSTAGRAM_ACCESS_TOKEN=${INSTAGRAM_ACCESS_TOKEN}
      - INSTAGRAM_USER_ID=${INSTAGRAM_USER_ID}
      - TIKTOK_ACCESS_TOKEN=${TIKTOK_ACCESS_TOKEN}
      - TIKTOK_CLIENT_KEY=${TIKTOK_CLIENT_KEY}
      - TIKTOK_CLIENT_SECRET=${TIKTOK_CLIENT_SECRET}
      - KEYWORD_RULES=${KEYWORD_RULES}
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
```

### .env

```bash
N8N_HOST=your-domain.com
N8N_ENCRYPTION_KEY=a-random-32-char-string-here

META_VERIFY_TOKEN=my_super_secret_verify_token
INSTAGRAM_ACCESS_TOKEN=EAAxxxxxxxxxxxxx
INSTAGRAM_USER_ID=123456789

TIKTOK_ACCESS_TOKEN=act.xxxxxxxxxxxxxxxx
TIKTOK_CLIENT_KEY=your_tiktok_client_key
TIKTOK_CLIENT_SECRET=your_tiktok_client_secret

# Paste your rules JSON (minified, on one line)
KEYWORD_RULES=[{"id":"rule_001","platform":"instagram","keyword":"leadership","match_type":"contains","event_name":"Youth Leadership Summit","event_link":"https://example.com/youth-leadership","dm_message":"Hey! 👋\n\nHere is the registration link for the {{event_name}}:\n{{event_link}}\n\nSee you there 🚀","public_reply":"Check your DMs 📩","active":true,"cooldown_hours":720,"expires_at":null,"max_dm_sends":null}]
```

### Start n8n

```bash
docker compose up -d
docker compose logs -f n8n
```

---

## Required Environment Variables

### Instagram Workflow

| Variable | Description | Example |
|---|---|---|
| `META_VERIFY_TOKEN` | Your chosen verification token for Meta webhooks | `my_secret_token_123` |
| `INSTAGRAM_ACCESS_TOKEN` | Page Access Token from Meta Developer Console | `EAAxxxxx...` |
| `INSTAGRAM_USER_ID` | Your Instagram Business Account User ID | `17841400000000000` |
| `KEYWORD_RULES` | JSON array of keyword rules (minified) | `[{...},{...}]` |

### TikTok Workflow

| Variable | Description | Example |
|---|---|---|
| `TIKTOK_ACCESS_TOKEN` | TikTok OAuth access token | `act.xxxxxxxx` |
| `TIKTOK_CLIENT_KEY` | TikTok app client key | `abc123xyz` |
| `TIKTOK_CLIENT_SECRET` | TikTok app client secret | `secret_abc123` |
| `KEYWORD_RULES` | Same JSON array as Instagram | `[{...},{...}]` |

---

## Setting Environment Variables in n8n UI

If you prefer not to use docker-compose environment variables:

1. Open n8n → **Settings** (bottom left)
2. Click **Environment Variables**
3. Add each variable as a key-value pair
4. Variables are encrypted and stored in n8n's database

Then in workflow Code nodes, access them as:
```javascript
const token = process.env.INSTAGRAM_ACCESS_TOKEN;
const rules = JSON.parse(process.env.KEYWORD_RULES || '[]');
```

And in HTTP Request node URL/header fields:
```
{{ $env.INSTAGRAM_ACCESS_TOKEN }}
```

---

## Importing the Workflows

1. Open n8n
2. Click **+ New Workflow** → **Import from file**
3. Select `workflows/instagram-comment-to-dm.json`
4. Repeat for `workflows/tiktok-comment-reply.json`

Or via n8n CLI:
```bash
n8n import:workflow --input=workflows/instagram-comment-to-dm.json
n8n import:workflow --input=workflows/tiktok-comment-reply.json
```

---

## Updating Rules Without Restarting

To add/modify keyword rules without restarting n8n:

1. Go to n8n **Settings → Environment Variables**
2. Update `KEYWORD_RULES` with your new JSON
3. Save — changes take effect on the next workflow execution

No workflow activation/deactivation needed.

---

## Workflow Analytics Access

The workflows store analytics in n8n's Static Workflow Data. To view them:

1. Open the Instagram or TikTok workflow
2. Click on the **Update Analytics** node
3. Add a temporary `Set` node and use: `$getWorkflowStaticData('global')`
4. Execute once to see the stored analytics JSON

Or query them via n8n's execution logs.

---

## Security Notes

- Always use **HTTPS** for your n8n instance (required by Meta and TikTok for webhooks)
- Rotate your `META_VERIFY_TOKEN` periodically
- Keep your `INSTAGRAM_ACCESS_TOKEN` secret — it grants access to send messages
- Consider adding IP allowlist for Meta/TikTok webhook IPs
- Add HMAC signature verification for webhook requests (see `docs/05-testing.md`)
