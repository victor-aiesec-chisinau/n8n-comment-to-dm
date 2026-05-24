# Rules Management

How to configure, add, and manage keyword rules for the Comment Auto-DM system.

---

## Rule Structure

Each rule is a JSON object with the following fields:

```json
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
```

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | ✅ | Unique identifier for this rule. Used for analytics and send count tracking. |
| `platform` | string | ✅ | `"instagram"` or `"tiktok"` |
| `keyword` | string | ✅ | The keyword to detect in comments |
| `match_type` | string | | How to match: `contains` (default), `exact`, `starts_with`, `word` |
| `event_name` | string | | Display name of the event (used in `{{event_name}}` template variable) |
| `event_link` | string | ✅ | The URL to send (registration, ticket, Discord, etc.) |
| `dm_message` | string | ✅ | The DM message to send (Instagram). Supports `{{event_name}}` and `{{event_link}}` |
| `public_reply` | string | | Public comment reply text. Leave empty to skip public reply. |
| `active` | boolean | | `true` = enabled, `false` = disabled |
| `cooldown_hours` | integer | | Hours before same user can receive DM again. Default: `720` (30 days) |
| `expires_at` | string/null | | ISO 8601 date when rule auto-disables. Example: `"2026-09-01T00:00:00Z"` |
| `max_dm_sends` | integer/null | | Maximum total DMs to send for this rule before auto-disabling. `null` = unlimited |

---

## Match Types

| Type | Behavior | Example: keyword `"leadership"` |
|---|---|---|
| `contains` | Comment includes the keyword anywhere | ✅ "i love leadership" ✅ "leadership summit" |
| `exact` | Comment is exactly the keyword | ✅ "leadership" ❌ "i love leadership" |
| `starts_with` | Comment begins with the keyword | ✅ "leadership is cool" ❌ "i love leadership" |
| `word` | Keyword appears as a whole word | ✅ "i love leadership" ❌ "proleadership" |

**Recommendation**: Use `contains` for most use cases. Use `exact` only when you need precise matching (e.g., to avoid false positives on long comments).

---

## Template Variables in dm_message

| Variable | Replaced with |
|---|---|
| `{{event_name}}` | The `event_name` field of the matched rule |
| `{{event_link}}` | The `event_link` field of the matched rule |

Example:
```
dm_message: "Hey! 👋\n\nRegister for {{event_name}} here:\n{{event_link}}"
```

Becomes:
```
Hey! 👋

Register for Youth Leadership Summit here:
https://example.com/youth-leadership
```

---

## Rule Priority

When a comment matches multiple rules, the **first matching rule wins** (rules are evaluated in array order).

**Best practice**: Put more specific rules first, generic rules last.

Example:
```json
[
  { "keyword": "erasmus 2026", "match_type": "contains", ... },
  { "keyword": "erasmus", "match_type": "contains", ... },
  { "keyword": "exchange", "match_type": "contains", ... }
]
```

---

## Managing Rules

### Option 1 — Edit the Environment Variable

1. Open `config/rules.example.json`
2. Edit the rules
3. Minify the JSON: `cat config/rules.example.json | python3 -m json.tool --compact`
4. Update the `KEYWORD_RULES` environment variable in n8n or your `.env` file

### Option 2 — n8n Code Node (Simple Override)

For quick testing, temporarily hardcode rules in the "Match Keyword Rule" Code node:

Replace:
```javascript
const rules = JSON.parse(process.env.KEYWORD_RULES || '[]');
```

With:
```javascript
const rules = [
  {
    id: "rule_001",
    platform: "instagram",
    keyword: "leadership",
    // ...
  }
];
```

Remember to switch back to env var loading for production.

---

## Example Rule Set by Use Case

### Event Registration (Eventbrite / Luma / Typeform)

```json
{
  "id": "rule_eventbrite",
  "platform": "instagram",
  "keyword": "tickets",
  "match_type": "contains",
  "event_name": "Tech Conference 2026",
  "event_link": "https://eventbrite.com/e/your-event",
  "dm_message": "Hey! 🎟️\n\nHere's the ticket link:\n{{event_link}}\n\nEarly bird pricing ends Friday!",
  "public_reply": "Tickets sent ✉️",
  "active": true,
  "cooldown_hours": 720,
  "expires_at": "2026-10-01T00:00:00Z",
  "max_dm_sends": 1000
}
```

### Community Invite (Discord / Telegram)

```json
{
  "id": "rule_discord",
  "platform": "instagram",
  "keyword": "discord",
  "match_type": "contains",
  "event_name": "Community Discord",
  "event_link": "https://discord.gg/yourinvite",
  "dm_message": "Welcome to the community! 🎉\n\nJoin here:\n{{event_link}}\n\nSee you inside!",
  "public_reply": "Invite sent 🎊",
  "active": true,
  "cooldown_hours": 8760,
  "expires_at": null,
  "max_dm_sends": null
}
```

### Erasmus / NGO Application

```json
{
  "id": "rule_erasmus",
  "platform": "instagram",
  "keyword": "erasmus",
  "match_type": "contains",
  "event_name": "Erasmus+ Youth Exchange",
  "event_link": "https://forms.example.com/erasmus-application",
  "dm_message": "Thanks for your interest 💙\n\nApplications are open until September 1st:\n{{event_link}}\n\nFeel free to message us with questions!",
  "public_reply": "Application link sent 📩",
  "active": true,
  "cooldown_hours": 720,
  "expires_at": "2026-09-01T00:00:00Z",
  "max_dm_sends": 500
}
```

### Webinar / Zoom

```json
{
  "id": "rule_webinar",
  "platform": "instagram",
  "keyword": "webinar",
  "match_type": "contains",
  "event_name": "Free Marketing Webinar",
  "event_link": "https://zoom.us/webinar/register/xyz",
  "dm_message": "Hey! 💻\n\nFree webinar registration:\n{{event_link}}\n\nLimited spots — register now!",
  "public_reply": "Link sent 📩",
  "active": true,
  "cooldown_hours": 168,
  "expires_at": "2026-06-15T18:00:00Z",
  "max_dm_sends": 300
}
```

### Hackathon

```json
{
  "id": "rule_hackathon",
  "platform": "tiktok",
  "keyword": "hackathon",
  "match_type": "contains",
  "event_name": "24h AI Hackathon",
  "event_link": "https://hackathon.example.com/register",
  "dm_message": "Spots are limited ⚡\n\nRegister for the hackathon:\n{{event_link}}\n\nGood luck! 🔥",
  "public_reply": "Register here 👉 {{event_link}}",
  "active": true,
  "cooldown_hours": 720,
  "expires_at": "2026-08-01T00:00:00Z",
  "max_dm_sends": 200
}
```

---

## Disabling vs Deleting Rules

- **To pause a rule**: Set `"active": false`
- **To auto-expire**: Set `"expires_at"` to a future ISO date
- **To delete permanently**: Remove the JSON object from the array

---

## Cooldown Recommendations

| Use Case | Recommended `cooldown_hours` |
|---|---|
| One-time event (conference, hackathon) | `720` (30 days) |
| Recurring events (monthly workshops) | `168` (7 days) |
| Community invite (Discord, Telegram) | `8760` (1 year) |
| Limited-time offer | `24` (1 day) |
| Testing | `0` (no cooldown) |
