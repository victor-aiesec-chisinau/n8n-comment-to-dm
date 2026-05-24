# 📣 Comment Auto-DM

> Automatically send event links, registration forms, and community invites to users who comment keywords on Instagram and TikTok.

Import two n8n workflows. Configure your keywords. Done.

---

## What It Does

1. User comments `leadership` on your Reel or TikTok video
2. The workflow detects the keyword
3. Instagram → sends a **private DM** with the event link
4. TikTok → posts a **public reply** with the event link (TikTok DM API is restricted)
5. Duplicate protection: same user won't receive the same link twice within the cooldown period
6. Analytics: tracks sends per keyword, per event

**Perfect for:**
- Youth exchanges & Erasmus programs
- Conferences & hackathons
- Workshop registrations (Eventbrite, Luma, Typeform)
- Webinars (Zoom, StreamYard)
- Community invites (Discord, Telegram)
- NGO volunteer programs

---

## Quick Start

```
1. Install n8n (cloud or self-hosted)
2. Import workflows/instagram-comment-to-dm.json
3. Import workflows/tiktok-comment-reply.json
4. Set environment variables (access tokens + keyword rules)
5. Activate workflows
6. Configure Meta & TikTok webhooks to point to your n8n URL
```

Detailed setup: [Instagram](docs/01-meta-app-setup.md) · [TikTok](docs/02-tiktok-setup.md) · [n8n Config](docs/03-n8n-environment.md)

---

## Project Structure

```
n8n-comment-to-dm/
├── workflows/
│   ├── instagram-comment-to-dm.json   ← Instagram: comment → DM
│   └── tiktok-comment-reply.json      ← TikTok: comment → public reply
├── config/
│   ├── rules.example.json             ← Example keyword rules (edit this)
│   └── templates.json                 ← Message templates reference
├── docs/
│   ├── 01-meta-app-setup.md           ← Create & configure Meta/Instagram App
│   ├── 02-tiktok-setup.md             ← Create & configure TikTok App
│   ├── 03-n8n-environment.md          ← n8n setup, Docker, env vars
│   ├── 04-rules-management.md         ← How to add/edit/expire rules
│   └── 05-testing.md                  ← Local testing & debugging
├── scripts/
│   └── test-webhook.sh                ← Simulate comment events via curl
└── README.md
```

---

## Workflow Architecture

### Instagram Workflow

```
[GET /instagram]                        [POST /instagram]
      │                                       │
[Verify Meta Challenge]             [Respond 200 OK immediately]
      │                                       │
[Return hub.challenge]            [Parse comment from webhook payload]
                                              │
                                    [Match keyword against rules]
                                              │
                                    [Check DM cooldown (30 days)]
                                              │
                                    [Send Instagram DM via Graph API]
                                              │
                                    [Post public comment reply]
                                              │
                                    [Update analytics]
```

### TikTok Workflow

```
[POST /tiktok]
      │
[Respond 200 OK immediately]
      │
[Parse TikTok comment event]
      │
[Match keyword against rules]
      │
[Check reply cooldown (30 days)]
      │
[Post public comment reply with event link]
      │
[Update analytics]
```

> **Why no TikTok DM?** TikTok's DM API is restricted to approved business partners. The TikTok workflow posts a public reply to the comment including the event link. [Apply for TikTok DM access →](docs/02-tiktok-setup.md#applying-for-dm-access)

---

## Environment Variables

| Variable | Workflow | Description |
|---|---|---|
| `META_VERIFY_TOKEN` | Instagram | Secret token for Meta webhook verification |
| `INSTAGRAM_ACCESS_TOKEN` | Instagram | Page Access Token from Meta Developer Console |
| `INSTAGRAM_USER_ID` | Instagram | Your Instagram Business Account ID |
| `TIKTOK_ACCESS_TOKEN` | TikTok | OAuth access token |
| `TIKTOK_CLIENT_KEY` | TikTok | App client key (for token refresh) |
| `TIKTOK_CLIENT_SECRET` | TikTok | App client secret |
| `KEYWORD_RULES` | Both | JSON array of keyword rules (see below) |

---

## Keyword Rules

Edit `config/rules.example.json` and set it as the `KEYWORD_RULES` environment variable in n8n.

```json
[
  {
    "id": "rule_001",
    "platform": "instagram",
    "keyword": "leadership",
    "match_type": "contains",
    "event_name": "Youth Leadership Summit",
    "event_link": "https://example.com/youth-leadership",
    "dm_message": "Hey! 👋\n\nHere is the registration link for the {{event_name}}:\n{{event_link}}\n\nSee you there 🚀",
    "public_reply": "Check your DMs 📩",
    "active": true,
    "cooldown_hours": 720,
    "expires_at": null,
    "max_dm_sends": null
  }
]
```

**Supported fields:**
- `platform` — `"instagram"` or `"tiktok"`
- `keyword` — word to detect in comments
- `match_type` — `contains` (default), `exact`, `starts_with`, `word`
- `event_link` — the URL to send (Eventbrite, Google Form, Discord, Luma, Zoom, etc.)
- `dm_message` — message template (supports `{{event_name}}` and `{{event_link}}`)
- `public_reply` — text to post as a public comment reply (optional)
- `active` — `true`/`false`
- `cooldown_hours` — how long before same user can receive again (default: `720` = 30 days)
- `expires_at` — ISO date when rule auto-disables (e.g., after event registration closes)
- `max_dm_sends` — max total sends before rule auto-disables (`null` = unlimited)

Full rule documentation: [docs/04-rules-management.md](docs/04-rules-management.md)

---

## DM Message Templates

Use these in your `dm_message` field:

**Simple:**
```
Hey! 👋

Here is the registration link:
{{event_link}}

See you there 🚀
```

**NGO/Volunteer:**
```
Thanks for your interest 💙

Applications are open here:
{{event_link}}

Feel free to message us if you have questions.
```

**Urgency:**
```
Spots are limited ⚡

Register here:
{{event_link}}
```

---

## Supported Event Link Types

| Platform | Example Link |
|---|---|
| Eventbrite | `https://eventbrite.com/e/your-event-123` |
| Luma | `https://lu.ma/your-event` |
| Google Forms | `https://forms.gle/yourformid` |
| Typeform | `https://yourname.typeform.com/to/formid` |
| Zoom Webinar | `https://zoom.us/webinar/register/xyz` |
| Discord Invite | `https://discord.gg/yourinvite` |
| Telegram | `https://t.me/yourchannel` |
| Any URL | Any valid URL works |

---

## Testing

```bash
chmod +x scripts/test-webhook.sh

# Simulate an Instagram comment with keyword "leadership"
./scripts/test-webhook.sh instagram leadership

# Simulate a TikTok comment with keyword "workshop"
./scripts/test-webhook.sh tiktok workshop

# Test Meta webhook verification
./scripts/test-webhook.sh verify
```

Full testing guide: [docs/05-testing.md](docs/05-testing.md)

---

## Analytics

Analytics are stored in n8n's workflow static data between executions. Each workflow tracks:

- Total DMs/replies sent per keyword
- First and last send timestamps
- Last 50 recipients (userId, commentId, comment preview, timestamp)
- Total sends per rule (for `max_dm_sends` enforcement)

To view analytics, see [docs/05-testing.md#checking-analytics](docs/05-testing.md#checking-analytics).

---

## Roadmap

- [ ] Click tracking (redirect URLs that track link opens)
- [ ] Admin dashboard (Next.js UI for managing rules)
- [ ] Multi-link rotation (A/B test different event links per keyword)
- [ ] AI comment intent matching (map natural language to keywords)
- [ ] Capacity-based auto-disable (stop after N registrations)
- [ ] Webhook signature verification (HMAC-SHA256 for Meta/TikTok)
- [ ] TikTok DM support (pending partner API access)
- [ ] Slack/email alerts for high-traffic keywords

---

## Setup Guides

| Step | Guide |
|---|---|
| 1. Create Meta App + get Instagram credentials | [docs/01-meta-app-setup.md](docs/01-meta-app-setup.md) |
| 2. Create TikTok Developer App | [docs/02-tiktok-setup.md](docs/02-tiktok-setup.md) |
| 3. Configure n8n (Docker or cloud) | [docs/03-n8n-environment.md](docs/03-n8n-environment.md) |
| 4. Add/edit keyword rules | [docs/04-rules-management.md](docs/04-rules-management.md) |
| 5. Test and verify everything works | [docs/05-testing.md](docs/05-testing.md) |

---

## License

MIT — free to use, self-host, and modify.
