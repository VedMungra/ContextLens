#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# log-session.sh  --  marks session boundaries in the usage log
#
# Fires on SessionStart and SessionEnd. Lets report.py count sessions, measure
# session duration, and detect how often people /clear between tasks (a direct
# signal for technique #8, context auditing).
# ---------------------------------------------------------------------------

set -uo pipefail

LOG_DIR="${CLAUDE_USAGE_LOG_DIR:-$HOME/.claude/usage-logs}"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0
LOG_FILE="$LOG_DIR/$(date -u +%Y-%m-%d).jsonl"

INPUT="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

echo "$INPUT" | jq -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg repo "$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")" \
  '{
     ts:      $ts,
     repo:    $repo,
     session: (.session_id // "unknown"),
     tool:    "__SESSION__",
     event:   (.hook_event_name // "unknown"),
     reason:  (.source // .reason // null)
   }' >> "$LOG_FILE" 2>/dev/null

exit 0
