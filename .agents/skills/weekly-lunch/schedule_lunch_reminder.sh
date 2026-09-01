#!/usr/bin/env bash
#
# schedule_lunch_reminder.sh -- schedule one daily lunch reminder for a chosen
# weekday at 8am Pacific.
#
# Usage: schedule_lunch_reminder.sh <YYYY-MM-DD> <message-text>
#
# Writes a dated one-shot cron entry (durable copy under data/.state/cron.d/,
# then installed live to /etc/cron.d/) that fires once at 08:00 on that date and
# runs send_lunch_reminder.sh, which posts the message and deletes the entry.
# Container clock is Pacific, so 08:00 here is 8am Pacific with no conversion.
set -euo pipefail

DATE="${1:?usage: schedule_lunch_reminder.sh <YYYY-MM-DD> <message-text>}"
TEXT="${2:?usage: schedule_lunch_reminder.sh <YYYY-MM-DD> <message-text>}"

[[ "$DATE" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})$ ]] || { echo "date must be YYYY-MM-DD" >&2; exit 1; }
MONTH="$((10#${BASH_REMATCH[2]}))"
DOM="$((10#${BASH_REMATCH[3]}))"

NAME="lunch-reminder-$DATE"
DUR="/home/user/workspace/data/.state/cron.d/$NAME"
WRAP="/home/user/workspace/system/libs/automations/with_agent_env.sh"
SEND="/home/user/workspace/.agents/skills/weekly-lunch/send_lunch_reminder.sh"
LOG="/var/log/supervisor/lunch-reminders.log"

# Escape the message for a single-quoted shell arg, then escape % for cron.
ESC="${TEXT//\'/\'\\\'\'}"
ESC="${ESC//%/\\%}"

mkdir -p /home/user/workspace/data/.state/cron.d
printf "0 8 %s %s *\troot\t%s bash %s %s '%s' >> %s 2>&1\n" \
  "$DOM" "$MONTH" "$WRAP" "$SEND" "$NAME" "$ESC" "$LOG" > "$DUR"
install -m 0644 "$DUR" "/etc/cron.d/$NAME"
echo "scheduled $NAME for $MONTH/$DOM 08:00 Pacific"
