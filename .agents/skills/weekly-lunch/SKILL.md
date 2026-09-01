---
name: weekly-lunch
description: Weekly lunch recommender + reminder cycle. Reads a team Notion "Lunch" page for the coming week, proposes 2-3 spec-matching options per weekday, waits for the user's picks, writes them onto the user's Notion line, and schedules an 8am Pacific Slack reminder for each chosen day. Runs automatically Sunday evening (via the weekly-lunch cron automation) and can also be run on demand.
---

# Weekly lunch cycle

You run the user's weekly lunch recommender. The whole spec, the food rules, and
the per-restaurant learnings live in the user's preference notes -- read them
first, every run.

## 0. Read the user's preferences (always)

Before doing anything, read the user's preference notes. This template ships
generalized examples under
[`example-preferences/`](example-preferences/) -- `nutrition-spec.example.md`
(nutrition targets), `operating-rules.example.md` (the operating rules), and a
`README.md` explaining them. On first setup, copy those into the user's own
private preference notes under `data/memories/` (e.g. `lunch-nutrition-criteria`,
`lunch-presentation-and-reminders`, `lunch-restaurant-notes`) and edit them to
the user's real targets; those notes are gitignored and intentionally not part
of this template. On every run thereafter, read the user's own notes.

They define: whose line the orders go on in the Notion doc; the nutrition spec;
the operating rules (you deliver complete balanced meals, never hand balancing
back; no "X or Y" inside one option; the doc gets order specs only, portion
guidance goes in the Slack reminder); and any restaurant gotchas the user has
learned.

## 1. Timezone

The reminder cron times are written in **local container time** with no UTC
conversion, so the container clock must be set to the user's own timezone --
confirm with `date`. The examples below assume America/Los_Angeles (Pacific);
PST/PDT is automatic once the clock is set. If `date` shows the wrong zone,
re-set the container timezone first.

## 2. Fetch the Notion Lunch page for the coming week

Page: `<YOUR_NOTION_LUNCH_PAGE_URL>` (the adopter sets this to their team's own
Notion "Lunch" page URL). Read via the notion-mcp latchkey service
(`notion-fetch`); responses are SSE, so strip the leading `data: `:

```bash
latchkey curl -s -X POST 'https://mcp.notion.com/mcp' \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"notion-fetch","arguments":{"id":"<YOUR_NOTION_LUNCH_PAGE_URL>"}}}'
```

Find the toggle for the **coming** week ("Week of <Month DD YYYY>"). Each weekday
is a sub-toggle whose `<summary>` line lists that day's restaurants (markdown
links), followed by a checkbox list of names (`- [ ] <name>`, etc.).

- If the coming week's toggle is not on the page yet, tell the user it hasn't
  been posted and stop (nothing to plan).
- If the user's line for the coming week **already has orders**, the week was
  already planned -- do not regenerate; stop.
- **If a latchkey call returns exit 7 or empty output**, the primary gateway is
  offline. There is no secondary gateway on this machine, so retry later; if it
  stays down, tell the user in chat. **If notion-mcp creds are expired** (auth
  error), you cannot refresh them headlessly -- Slack the user to
  re-authenticate, then stop.

## 3. Build 2-3 options per weekday

Each option is a **single definite recommendation** meeting the spec (~500-650
cal, >=35g lean protein, <=5g sat fat est., a soluble-fiber source most days,
~1/2 veg + 1/4 protein + 1/4 carb, warm preferred, tasty) with estimated macros.
Vet **every** listed restaurant (don't skip any); prefer the simplest dish that
works as-is; lead with lean **chicken breast** most days and at most one salmon
option/day. If a dish is deficient (e.g. a salmon bento with near-zero veg),
**complete it yourself** with a specific second item from another of that day's
restaurants -- never tell the user to "add a side". DoorDash / menu aggregators
are Cloudflare-blocked; use each restaurant's own site + web search for menus and
nutrition.

### Every dish must be verified real -- for EVERY restaurant, no exceptions

This rule applies to all restaurants on every day, not to any one place. Never
invent a menu item. Before you recommend any dish:

- **Confirm the exact item exists on that restaurant's current menu** from a
  concrete source -- ideally the restaurant's own site / online-ordering page,
  otherwise a listing that shows actual item names. Recommend items by their
  real menu name; prefer quoting the name as listed.
- **Confirm any protein or customization you name is actually offered** (e.g.
  "with tofu", "chicken breast not thigh", "no cotija"). If the base dish is
  real but a swap isn't confirmed, don't assert the swap.
- **Uncertainty is a hard stop, not something to smooth over.** If your research
  says anything like "couldn't confirm", "results don't confirm", "menu may be
  AI-generated", or you're relying on what a place "probably" has -- do NOT turn
  that into a confident pick. Resolve it first (fetch the actual menu / ordering
  page), or drop that option and recommend a different confirmed dish. If a whole
  restaurant can't be verified, say so in the presentation rather than guessing.
- A "single definite recommendation" (the rule above) means definite AND real --
  definiteness never licenses invention. When in doubt, under-promise: present
  only what you've confirmed.

(This rule exists because a "bibimbap with tofu" was once recommended at a
restaurant that has no bibimbap and no tofu -- the research had flagged it as
unconfirmed and it was asserted anyway. Verify, every time.)

## 4. Present the week, wait for picks

Post the whole week to the user as your chat output: for each weekday, the 2-3
options (with macros) and that day's full restaurant list. **Do not write to
Notion yet.** Wait for the user's picks (e.g. "Tue 1, Wed 2").

## 5. Write picks to Notion (order spec only)

For each chosen day, write the order onto the user's line using
`notion-update-page` with `command:"update_content"` and a `content_updates`
search/replace. The name rows are identical across weekdays, so anchor `old_str`
to the day-unique `<summary>` line and span down through that day's
`- [ ] <name>` line; `new_str` is identical except the user's line carries the
order. Match the exact text from `notion-fetch` (real tabs/newlines). Write the
**order spec only** -- no eating notes. After writing, re-fetch and verify each
pick sits under the right day and no one else's row changed.

## 6. Schedule the daily 8am reminders

For each chosen weekday, schedule an 8am Pacific Slack reminder carrying that
day's dish + eating/portion instruction (the guidance that does NOT go in Notion):

```bash
bash .agents/skills/weekly-lunch/schedule_lunch_reminder.sh <YYYY-MM-DD> "Today's lunch: <DISH>. <EATING INSTRUCTION>."
```

This writes a one-shot cron entry that fires once at 08:00 local time that day,
posts to the user's Slack DM (channel `<YOUR_SLACK_DM_CHANNEL_ID>`, supplied via
the `LUNCH_SLACK_CHANNEL` env var / the fallback in `send_lunch_reminder.sh`),
and removes itself. No emojis.

To find your DM channel id: call Slack's `conversations.open` with your own
Slack user id (look it up via `auth.test` / `users.list`), which returns a
`D...` channel id for your self-DM.

## 7. Cadence

The Sunday-evening cron automation re-runs this skill every week automatically --
there is nothing to re-arm. Running this skill on demand for the coming week is
safe: step 2 stops early if that week is already planned.
