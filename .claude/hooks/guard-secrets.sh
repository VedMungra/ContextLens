#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# guard-secrets.sh  --  blocks reads/writes/greps/globs/bash calls touching
# secret-bearing files
#
# OPTIONAL. Not part of the three cost techniques -- included because it is
# the single most requested guardrail and it makes engineers want to install
# the kit. Adoption is the metric that matters; this buys adoption.
#
# Fires on PreToolUse for Read/Edit/Write/Bash/Grep/Glob. Exit 2 blocks the
# call.
#
# Fails CLOSED: if jq is missing, the raw hook payload is grepped against the
# blocked patterns instead of being allowed through -- over-blocking is the
# correct failure mode for a secrets guard.
# ---------------------------------------------------------------------------

set -uo pipefail

INPUT="$(cat)"

# Extend this list to match your organisation's layout. Anchored to the end
# of the (isolated) field value -- used once jq has pulled a single field
# (file_path, command, ...) out of the payload.
BLOCKED_PATTERNS=(
  '\.env($|\.)'
  '(^|/)secrets?/'
  '\.pem$'
  '\.key$'
  'id_rsa'
  'credentials(\.json|\.yaml|\.yml)?$'
  '\.aws/'
  'serviceaccount.*\.json$'
)

# Same intent, unanchored -- used to scan the raw JSON payload text when jq
# is unavailable. There, the match is never the whole string: it sits inside
# quotes/braces (e.g. `"command":"cat .env"}}`), so a trailing "$" anchor
# would never fire. A trailing non-identifier char (or end of string) stands
# in for the boundary instead.
BLOCKED_PATTERNS_RAW=(
  '\.env([^A-Za-z0-9_.-]|$)'
  '(^|/|")secrets?/'
  '\.pem([^A-Za-z0-9_.-]|$)'
  '\.key([^A-Za-z0-9_.-]|$)'
  'id_rsa'
  'credentials(\.json|\.yaml|\.yml)?([^A-Za-z0-9_.-]|$)'
  '\.aws/'
  'serviceaccount.*\.json([^A-Za-z0-9_.-]|$)'
)

matches_any() {
  local value="$1"
  shift
  local pattern
  for pattern in "$@"; do
    if grep -Eq "$pattern" <<<"$value"; then
      return 0
    fi
  done
  return 1
}

block() {
  echo "Blocked by team policy: '$1' matches a secret-bearing path pattern. Ask the file owner for the values you need, or use the documented local override." >&2
  exit 2
}

if ! command -v jq >/dev/null 2>&1; then
  # jq is unavailable -- fail CLOSED rather than allowing everything through.
  # Grepping the raw payload is blunter than field-aware matching, but a
  # secrets guard should over-block, not silently disable itself.
  if matches_any "$INPUT" "${BLOCKED_PATTERNS_RAW[@]}"; then
    block "(raw payload, jq unavailable)"
  fi
  exit 0
fi

resolve_path() {
  # Neutralise traversal (config/../.env) and symlinks where realpath exists,
  # so the pattern match can't be dodged by a path string alone.
  if command -v realpath >/dev/null 2>&1; then
    realpath -m -- "$1" 2>/dev/null || printf '%s' "$1"
  else
    printf '%s' "$1"
  fi
}

check_path_field() {
  local raw="$1"
  [ -z "$raw" ] && return 0
  local resolved
  resolved="$(resolve_path "$raw")"
  if matches_any "$raw" "${BLOCKED_PATTERNS[@]}" || matches_any "$resolved" "${BLOCKED_PATTERNS[@]}"; then
    block "$raw"
  fi
}

check_raw_field() {
  local raw="$1"
  [ -z "$raw" ] && return 0
  matches_any "$raw" "${BLOCKED_PATTERNS[@]}" && block "$raw"
}

# Read/Edit/Write
check_path_field "$(jq -r '.tool_input.file_path // empty' <<<"$INPUT")"

# Bash -- a full shell command string, not a path; do not realpath-resolve it.
check_raw_field "$(jq -r '.tool_input.command // empty' <<<"$INPUT")"

# Grep/Glob
check_path_field "$(jq -r '.tool_input.path // empty' <<<"$INPUT")"
check_path_field "$(jq -r '.tool_input.pattern // empty' <<<"$INPUT")"

exit 0
