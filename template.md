---
title: "Weekly Lunch Assistant"
description: "A weekly cycle that reads a team Notion lunch page, recommends nutrition-spec-matching options for each weekday, writes the chosen picks back to the doc, and DMs an 8am portion reminder each weekday over Slack."
thumbnail: "template.svg"
version: v1
format: v2
---

# Weekly Lunch Assistant

This file is the manifest for the **Weekly Lunch Assistant** template (slug:
`lunch-assistant`). It is the one document a future agent reads to understand,
present, and adapt this template. If you are an agent in a mind that was
created from this template, this file is your script: read all of it, then
follow "How to adapt it" below.

## What it is

A weekly cycle that reads a team Notion lunch page, recommends nutrition-spec-matching options for each weekday, writes the chosen picks back to the doc, and DMs an 8am portion reminder each weekday over Slack.

This template turns "what should I eat for lunch this week?" into a short,
repeatable ritual. Each week it reads a team Notion "Lunch" page listing the
restaurants offered on each weekday, and for every day it proposes two or three
complete, balanced lunch options -- each a single, definite, verified-real dish
that meets a nutrition spec you configure (calorie band, lean-protein floor,
saturated-fat ceiling, a plate ratio, and so on), with estimated macros. It
presents the whole week to you in chat and waits for your picks. Once you choose,
it writes the order onto your line in the Notion doc (the order spec only) and
schedules a one-shot 8am reminder for each chosen weekday that DMs you that day's
dish plus any portion guidance over Slack -- then removes itself. It can run
automatically on Sunday evenings via the weekly-lunch cron automation, or on
demand any time. You supply your own nutrition targets and operating rules
through preference notes; the template ships generalized examples to start from.

## How it works

The snapshot includes these paths (each is a repo-root-relative path copied
from the original mind onto a clean default-workspace-template base):

- `.agents/skills/weekly-lunch`

`.agents/skills/weekly-lunch` is a **skill** -- a set of instructions the mind's
own agent follows, not a standalone service. It contains:

- `SKILL.md` -- the full playbook the agent runs each week: read the user's
  preference notes, confirm the timezone, fetch the coming week from the Notion
  lunch page (via the `notion-mcp` latchkey service), build 2-3 verified-real
  options per weekday, present the week and wait for the user's picks, write the
  picks onto the user's Notion line, and schedule the daily reminders.
- `schedule_lunch_reminder.sh` -- given a date and a message, writes a dated
  one-shot cron entry (a durable copy under `data/.state/cron.d/`, installed live
  to `/etc/cron.d/`) that fires once at 08:00 local time on that day.
- `send_lunch_reminder.sh` -- what that cron entry runs: it posts the day's
  message to the user's Slack DM via `latchkey curl` against
  `chat.postMessage`, then deletes its own cron entry so it never fires again.
- `example-preferences/` -- generalized example preference files
  (`nutrition-spec.example.md`, `operating-rules.example.md`, and a `README.md`)
  the adopter copies into their own private notes under `data/memories/` and
  edits to their own targets.

There is no long-running app or port here. The pieces wire together through the
stock workspace machinery: the reminder cron entries run through the
`system/libs/automations` env wrapper (`with_agent_env.sh`), and both scripts
reach Slack and Notion through `latchkey`. Weekly execution is driven by the
existing weekly-lunch cron automation (Sunday evening), which simply invokes this
skill; on-demand runs invoke it the same way. The reminder scripts shell out to
`jq` to build the Slack JSON payload.

## Recipe

This template is version `v1`. It is not a fork of the
workspace it came from -- it is DERIVED from it by a recipe: include these
paths, leave these out, apply these published-version rules. An update re-runs
the recipe against the current workspace and publishes the result as the next
version, so anything excluded stays excluded even though it still exists in the
source workspace.

The recipe is machine-read, so it lives in the sibling
[`template.toml`](template.toml) -- its `[recipe]` table -- along with
the structured requirements and the environment this template needs
installed. That file is authoritative for all of it; this one holds the prose.

## Requirements

Everything the adopting mind must deal with before this template is really
theirs. Two kinds of entry, handled at different times:

- **Activation** -- what must be SET UP before anything runs, in the
  machine-readable `requires_` forms below. The adopting agent acts on these
  ITSELF, first, before asking anything.
- **Adaptation** -- what must be DECIDED or REWIRED, in prose. Worked through
  interactively with the user, after activation.

**Activation** -- the adopting agent initiates each of these via a latchkey
permission request during setup (it must not merely mention them):

- requires_permission: slack-api / slack-chat-write (user-approved; adopting agent initiates during setup) -- DM the daily reminder
- requires_permission: slack-api / slack-conversations-write (user-approved; adopting agent initiates during setup) -- open the DM channel
- requires_permission: slack-api / slack-auth-read (user-approved; adopting agent initiates during setup) -- confirm the Slack user/DM channel
- requires_permission: slack-api / slack-users-read (user-approved; adopting agent initiates during setup) -- look up the user id to derive the DM channel
- requires_permission: notion-mcp-api / notion-mcp-read-all (user-approved; adopting agent initiates during setup) -- read the Notion lunch page
- requires_permission: notion-mcp-api / notion-mcp-update-page (user-approved; adopting agent initiates during setup) -- write picks onto the user's line

There are no secrets to supply, and the skill does not call an LLM directly (it
is a set of instructions the mind's own agent follows), so there is no
`requires_llm` entry.

**Adaptation** -- worked through interactively with the user, after activation:

- The Notion lunch-page URL is a placeholder (`<YOUR_NOTION_LUNCH_PAGE_URL>` in
  `SKILL.md`). The adopter must point it at their team's own Notion "Lunch" page,
  structured as weekly toggles with a per-weekday restaurant list and a checkbox
  list of names.
- The Slack DM channel id is a placeholder. The adopter must supply their own DM
  channel id (a `D...` id) via the `LUNCH_SLACK_CHANNEL` environment variable or
  the fallback in `send_lunch_reminder.sh`; find it by opening a self-DM with
  `conversations.open` using your own Slack user id.
- The nutrition targets and operating rules are not shipped as live config. The
  adopter must create their own private preference notes under `data/memories/`
  from the shipped `example-preferences/` and edit them to their own goals
  (including whose line the orders go on in the Notion doc).
- The reminder cron times are written in local container time with no UTC
  conversion. The adopter must set the container clock to their own timezone, or
  the 8am reminders will fire at the wrong hour.
- This Slack token type cannot use Slack's native `chat.scheduleMessage`, which
  is why reminders are delivered through one-shot cron entries rather than
  scheduled Slack messages; an adopter on a token that supports scheduling could
  simplify this, but the cron path works as shipped.

## Environment

What this template needs INSTALLED, beyond what the template already has.
Declared in `template.toml`'s `[environment]` table; an adopting mind
converges it at ITS OWN pinned apt snapshot timestamp, so package versions come
out consistent with the rest of that mind's environment rather than frozen to
whatever this publisher happened to have.

- `jq`: the reminder scripts shell out to `jq` to build the Slack
  `chat.postMessage` JSON payload.

Nothing else beyond the stock workspace environment. The reminder scripts also
use `latchkey` (to reach Slack and Notion) and the
`system/libs/automations` env wrapper (`with_agent_env.sh`) for the cron entries,
but both of those ship in the base template already, so only `jq` is declared.

## How to adapt it

Instructions for the NEXT agent -- the one adapting this template into a
new mind. This is the `use-template` skill's template path; in short:

1. Read this entire file first, especially "Requirements" below. It holds two
   kinds of entry and they are handled at different times: the machine-readable
   `requires_` lines are ACTIVATION (set them up before anything runs), and
   the prose bullets are ADAPTATION (decide or rewire them afterwards).
2. Present the template to the user in plain, non-technical language: what
   it is, what it does, and what it needs from them (name the activation
   requirements).
3. Ask whether they want to use the same connectors (e.g. their own Slack).
   If YES: ACTIVATE FIRST -- initiate every `requires_permission` line NOW
   via a latchkey permission request (see the `latchkey` skill; the request
   opens the approval/login flow in the minds app), wire up any
   `requires_secret` values, start the services, and get the app showing
   THE USER'S OWN DATA. Done for a data-backed app means the user can open it
   and see their own data -- NOT that a service starts or an endpoint returns
   200. Then tell them it is live and to take a look.
4. Only AFTER that (or immediately, if they chose different connectors -- the
   swap is then the first adaptation) ask: "How do you want to adapt it?"
5. Work through each requirement interactively, one at a time. Translate each
   into plain language, ask for a decision only when you genuinely need one,
   and resolve the obvious ones yourself.
6. When done, append a dated entry to "Adaptation history" below (never
   rewrite earlier entries) and commit.

## Publication history

This template's changelog: what each published version changed. The PUBLISHER
appends one entry per version (newest last); earlier entries are never rewritten.
This is distinct from "Adaptation history" below, which is the ADOPTERS' log.

### v1 (2026-08-31) -- Initial publish of the Weekly Lunch Assistant (Notion recommender + Slack 8am reminders + generalized example preferences).

## Adaptation history

Each mind that adapts this template appends one dated entry below. Earlier
entries are never rewritten.
