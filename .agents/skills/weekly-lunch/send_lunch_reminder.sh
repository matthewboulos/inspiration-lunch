#!/usr/bin/env bash
#
# send_lunch_reminder.sh -- post one daily lunch instruction to the user on
# Slack, then remove its own one-shot cron entry so it never fires again.
#
# Usage: send_lunch_reminder.sh <cron-entry-name> <message-text>
#
# Invoked by a dated one-shot cron entry that schedule_lunch_reminder.sh wrote
# (fires once at 8am Pacific on the target day). Container clock is Pacific, so
# no timezone conversion is involved. There is no secondary latchkey gateway on
# this machine, so a send only succeeds when the primary gateway is online; two
# attempts are made before giving up.
set -euo pipefail

# cron's scrubbed PATH (kept by the env wrapper) omits /usr/local/bin, where
# latchkey lives -- make sure it is reachable.
export PATH="/usr/local/bin:$PATH"

NAME="${1:?usage: send_lunch_reminder.sh <cron-entry-name> <message-text>}"
TEXT="${2:?usage: send_lunch_reminder.sh <cron-entry-name> <message-text>}"
# Your own Slack DM channel id (a "D..." id). Set LUNCH_SLACK_CHANNEL in the
# environment, or replace the fallback below. Find it by opening a DM to
# yourself: call conversations.open with your own Slack user id (see SKILL.md).
CHANNEL="${LUNCH_SLACK_CHANNEL:-REPLACE_WITH_YOUR_SLACK_DM_CHANNEL_ID}"

BODY="$(jq -nc --arg c "$CHANNEL" --arg t "$TEXT" '{channel:$c, text:$t}')"

send() {
  latchkey curl -s -X POST 'https://slack.com/api/chat.postMessage' \
    -H 'Content-Type: application/json' -d "$BODY"
}

RESP="$(send || true)"
if ! printf '%s' "$RESP" | grep -q '"ok":true'; then
  sleep 30
  RESP="$(send || true)"
fi

# One-shot: remove both copies so a dated cron line (which would otherwise recur
# annually) never fires again.
rm -f "/etc/cron.d/$NAME" "/home/user/workspace/data/.state/cron.d/$NAME"

printf '%s\n' "$RESP"
printf '%s' "$RESP" | grep -q '"ok":true' || { echo "send_lunch_reminder: Slack send FAILED for $NAME" >&2; exit 1; }
