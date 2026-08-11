#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# doctor.sh -- diagnose why ContextLens hooks might not be logging.
#
# report.py cannot tell "this person never used Claude Code" from "this
# person's hook was silently broken for two weeks" -- both look like an
# empty log directory. Run this instead of staring at that ambiguity.
#
# Usage (from the repo root):
#   bash scripts/doctor.sh
#
# Prints PASS/FAIL for each check and exits non-zero if anything failed.
# ---------------------------------------------------------------------------

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "PASS  $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL  $1"
  [ -n "${2:-}" ] && echo "      -> $2"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo "ContextLens doctor -- checking $REPO_ROOT"
echo

# ---------------------------------------------------------------------------
# 1. jq installed
# ---------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  pass "jq installed ($(jq --version 2>/dev/null))"
else
  fail "jq installed" "Hooks lose most of their logic without jq. Install: see docs/INSTALL.md § Prerequisites."
fi

# ---------------------------------------------------------------------------
# 2. hooks executable
# ---------------------------------------------------------------------------
if [ -d .claude/hooks ]; then
  non_exec=()
  for f in .claude/hooks/*.sh; do
    [ -e "$f" ] || continue
    [ -x "$f" ] || non_exec+=("$f")
  done
  if [ "${#non_exec[@]}" -eq 0 ]; then
    pass "hooks executable"
  else
    fail "hooks executable" "Not executable: ${non_exec[*]}. Fix: chmod +x .claude/hooks/*.sh"
  fi
else
  fail "hooks executable" ".claude/hooks not found -- run this from the repo root"
fi

# ---------------------------------------------------------------------------
# 3. no CRLF line endings
# ---------------------------------------------------------------------------
if [ -d .claude/hooks ]; then
  crlf=()
  for f in .claude/hooks/*.sh; do
    [ -e "$f" ] || continue
    if grep -qU $'\r' "$f" 2>/dev/null; then
      crlf+=("$f")
    fi
  done
  if [ "${#crlf[@]}" -eq 0 ]; then
    pass "no CRLF line endings in hooks"
  else
    fail "no CRLF line endings in hooks" "CRLF found in: ${crlf[*]}. Fix: sed -i 's/\r\$//' .claude/hooks/*.sh"
  fi
else
  fail "no CRLF line endings in hooks" ".claude/hooks not found"
fi

# ---------------------------------------------------------------------------
# 4. settings.json valid JSON with 4 events configured
# ---------------------------------------------------------------------------
if [ ! -f .claude/settings.json ]; then
  fail "settings.json valid JSON with 4 events configured" ".claude/settings.json not found"
elif command -v jq >/dev/null 2>&1; then
  if jq empty .claude/settings.json >/dev/null 2>&1; then
    event_count="$(jq '.hooks | keys | length' .claude/settings.json 2>/dev/null)"
    if [ "$event_count" = "4" ]; then
      pass "settings.json valid JSON with 4 events configured"
    else
      fail "settings.json valid JSON with 4 events configured" \
        "Found $event_count event(s), expected 4 (PreToolUse, PostToolUse, SessionStart, SessionEnd)."
    fi
  else
    fail "settings.json valid JSON with 4 events configured" "settings.json is not valid JSON."
  fi
elif command -v python3 >/dev/null 2>&1; then
  if python3 -c "
import json, sys
d = json.load(open('.claude/settings.json', encoding='utf-8'))
sys.exit(0 if len(d.get('hooks', {})) == 4 else 1)
" 2>/dev/null; then
    pass "settings.json valid JSON with 4 events configured"
  else
    fail "settings.json valid JSON with 4 events configured" "Invalid JSON, or not exactly 4 events."
  fi
else
  fail "settings.json valid JSON with 4 events configured" "Need jq or python3 to check this."
fi

# ---------------------------------------------------------------------------
# 5. correct platform config (shell form required on Windows)
# ---------------------------------------------------------------------------
uname_out="$(uname -s 2>/dev/null || echo unknown)"
is_windows=0
case "$uname_out" in
  MINGW* | MSYS* | CYGWIN*) is_windows=1 ;;
esac

if [ -f .claude/settings.json ]; then
  # grep -c prints "0" (not nothing) and still exits 1 when there are no
  # matches, so a "|| echo 0" fallback here would double up the output.
  shell_form_count="$(grep -c '"shell": "bash"' .claude/settings.json 2>/dev/null)"
  shell_form_count="${shell_form_count:-0}"
  if [ "$is_windows" -eq 1 ]; then
    if [ "$shell_form_count" = "4" ]; then
      pass "correct platform config (Windows, shell form, count=4)"
    else
      fail "correct platform config (Windows, shell form, count=4)" \
        "Found $shell_form_count, expected 4. Fix: cp .claude/settings-windows.json .claude/settings.json"
    fi
  else
    if [ "$shell_form_count" = "0" ]; then
      pass "correct platform config (non-Windows, command form)"
    else
      fail "correct platform config (non-Windows, command form)" \
        "settings.json is using the Windows shell form on a non-Windows platform ($uname_out)."
    fi
  fi
else
  fail "correct platform config" ".claude/settings.json not found"
fi

# ---------------------------------------------------------------------------
# 6. live end-to-end run of log-usage.sh
# ---------------------------------------------------------------------------
if [ -x .claude/hooks/log-usage.sh ]; then
  tmp_log_dir="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/contextlens-doctor-$$")"
  mkdir -p "$tmp_log_dir"

  CLAUDE_USAGE_LOG_DIR="$tmp_log_dir" bash .claude/hooks/log-usage.sh <<'PAYLOAD' >/dev/null 2>&1
{"session_id":"doctor","hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"/doctor/check.txt"},"tool_response":"doctor check payload"}
PAYLOAD

  log_file="$tmp_log_dir/$(date -u +%Y-%m-%d).jsonl"
  if [ -s "$log_file" ]; then
    line="$(tail -n 1 "$log_file")"
    if command -v jq >/dev/null 2>&1 && echo "$line" | jq -e 'has("response_bytes") and (.response_bytes | type == "number")' >/dev/null 2>&1; then
      pass "live end-to-end run of log-usage.sh produced valid output"
    elif command -v jq >/dev/null 2>&1; then
      fail "live end-to-end run of log-usage.sh produced valid output" "Log line is missing a numeric response_bytes field: $line"
    else
      pass "live end-to-end run of log-usage.sh produced output (jq unavailable to validate structure)"
    fi
  else
    fail "live end-to-end run of log-usage.sh produced valid output" \
      "No log written to $log_file. Run: CLAUDE_USAGE_LOG_DIR=/tmp/x bash .claude/hooks/log-usage.sh <<< '{}' to see the raw error."
  fi

  rm -rf "$tmp_log_dir" 2>/dev/null
else
  fail "live end-to-end run of log-usage.sh produced valid output" ".claude/hooks/log-usage.sh missing or not executable"
fi

echo
echo "$PASS_COUNT passed, $FAIL_COUNT failed."

[ "$FAIL_COUNT" -eq 0 ]
