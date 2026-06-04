# Pending improvements for vt1/wfs

## 1. Rule limits: expires_at and max_dm_sends

**What:** Add two optional fields to each rule in `KEYWORD_RULES` that cap when and how many times a rule can fire.

**expires_at**
A date string (e.g. `"2026-07-10T23:59:00Z"`). If set and the current time is past it, skip the rule entirely. Useful for event promotions that have a registration deadline — the rule stops firing automatically instead of sending people a dead link.

**max_dm_sends**
An integer (e.g. `100`). If set, the rule stops firing after it has sent that many DMs total. Useful to cap costs or API quota on high-traffic posts.

**Where to implement:** `Match Keywords` node — add to the `activeRules` filter:
```js
const activeRules = rules.filter(r => {
  if (!r.active || (!r.platform || r.platform !== 'instagram')) return false;
  if (r.expires_at && new Date(r.expires_at) < new Date()) return false;
  // max_dm_sends requires a send count — see note below
  return true;
});
```

**Note on max_dm_sends in this architecture:** The original workflow tracked send counts in n8n static data. Here, the Notion DM log already records every send, so the count could be queried from there. The simplest approach: add a `sendCount` Notion property to the Instagram DM database and increment it on each `Update DM Log`. Then query it in `Check DM Cooldown` (which already runs a Notion query) and pass it forward so `Match Keywords` can compare against `max_dm_sends`.

---

## 3. Configurable public reply text per rule

**What:** The `Post Public Comment Reply` node currently hardcodes `"✅ Check your DMs!"`. This should come from the matched rule, and if the rule has no public reply set, the node should be skipped entirely.

**Where to implement:**
- Add a `publicReply` field to each rule in `KEYWORD_RULES` (e.g. `"publicReply": "✅ Check your DMs! Link sent."`)
- Pass it through `Prepare Matched Data` (add a new assignment row: `publicReply → $json.publicReply`)
- Add an IF node between `Check DM Send Success` and `Post Public Comment Reply` that checks `$json.publicReply` is not empty
- Update `Post Public Comment Reply` jsonBody to use `$('Prepare Matched Data').item.json.publicReply` instead of the hardcoded string

**Current flow:**
`Check DM Send Success (true)` → `Post Public Comment Reply` → `Update DM Log`

**New flow:**
`Check DM Send Success (true)` → `Has Public Reply? (IF)` → true: `Post Public Comment Reply` → `Update DM Log`
                                                           → false: `Update DM Log`
