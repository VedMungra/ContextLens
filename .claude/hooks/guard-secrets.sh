#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# guard-secrets.sh  --  blocks reads/writes to secret-bearing files
#
# OPTIONAL. Not part of the three cost techniques -- included because it is
# the single most requested guardrail and it makes engineers want to install
# the kit. Adoption is the metric that matters; this buys adoption.
#
# Fires on PreToolUse for Read/Edit/Write. Exit 2 blocks the call.
# ---------------------------------------------------------------------------

set -uo pipefail

INPUT="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"
[ -z "$FILE_PATH" ] && exit 0

# Extend this list to match your organisation's layout.
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

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$FILE_PATH" | grep -Eq "$pattern"; then
    echo "Blocked by team policy: '$FILE_PATH' matches a secret-bearing path pattern. Ask the file owner for the values you need, or use the documented local override." >&2
    exit 2
  fi
done

exit 0
