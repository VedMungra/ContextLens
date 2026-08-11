#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# log-usage.sh  --  Claude Code usage attribution logger
#
# Fires on PostToolUse for every tool call. Appends one JSON line per call to
# a local log. Records NO file contents, NO prompts, NO source code -- only
# structural metadata (which tool, how big the result was, which agent).
#
# Read by scripts/report.py to produce the before/after efficiency report.
#
# Privacy: see docs/PRIVACY.md. Everything stays on the engineer's machine
# unless they choose to share their log file.
# ---------------------------------------------------------------------------

set -uo pipefail

LOG_DIR="${CLAUDE_USAGE_LOG_DIR:-$HOME/.claude/usage-logs}"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

LOG_FILE="$LOG_DIR/$(date -u +%Y-%m-%d).jsonl"

# Read the hook payload from stdin.
INPUT="$(cat)"

# jq is required. Fail silently so a missing dependency never blocks anyone's
# work -- a broken measurement tool must not break the thing being measured.
command -v jq >/dev/null 2>&1 || exit 0

# Extract structural metadata only.
#   response_bytes = size of the tool result that entered the context window.
#                    This is our proxy for "context consumed". It is NOT a
#                    token count -- see docs/MEASUREMENT.md for why that
#                    distinction matters when you report numbers.
#   agent_type     = present only when the call happened inside a subagent,
#                    which is how we measure delegation share.
echo "$INPUT" | jq -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg repo "$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")" \
  '{
     ts:             $ts,
     repo:           $repo,
     session:        (.session_id      // "unknown"),
     prompt_id:      (.prompt_id       // null),
     tool:           (.tool_name       // "unknown"),
     agent_type:     (.agent_type      // "main"),
     response_bytes: ((.tool_response // "") | tostring | length),
     input_bytes:    ((.tool_input    // "") | tostring | length),
     file:           (.tool_input.file_path // null
                       | if . == null then null else (. | split("/") | last) end)
   }' >> "$LOG_FILE" 2>/dev/null

exit 0
