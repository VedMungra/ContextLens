#!/usr/bin/env python3
"""
report.py -- turn Claude Code usage logs into an efficiency report.

Reads the JSONL files written by .claude/hooks/log-usage.sh and reports the
metrics that actually move when you apply context auditing (#8) and model
right-sizing (#1).

Usage:
    python3 scripts/report.py                          # all logs, single summary
    python3 scripts/report.py --before 2026-08-20      # baseline vs. everything after
    python3 scripts/report.py --log-dir ~/other/logs
    python3 scripts/report.py --json                   # machine-readable

Requires: Python 3.8+, no third-party packages.

IMPORTANT -- read docs/MEASUREMENT.md before quoting any number from this
script. `response_bytes` is a proxy for context volume, not a token count and
not a bill. Reporting it as "we cut tokens by N%" is a claim this tool does
not support.
"""

import argparse
import json
import os
import statistics
import sys
from collections import defaultdict
from datetime import datetime, date
from pathlib import Path

SESSION_MARKER = "__SESSION__"


# --------------------------------------------------------------------------
# Loading
# --------------------------------------------------------------------------

def load_events(log_dir: Path):
    """Read every .jsonl file in log_dir. Skip malformed lines silently --
    a half-written line from a crashed hook should not kill the report."""
    events = []
    if not log_dir.exists():
        sys.exit(f"No log directory at {log_dir}. Has anyone run Claude Code "
                 f"since installing the kit?")

    for path in sorted(log_dir.glob("*.jsonl")):
        with path.open(encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    events.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return events


def event_date(ev):
    ts = ev.get("ts", "")
    try:
        return datetime.strptime(ts[:10], "%Y-%m-%d").date()
    except ValueError:
        return None


# --------------------------------------------------------------------------
# Aggregation
# --------------------------------------------------------------------------

def summarise(events):
    """Collapse a list of events into the metrics we care about."""
    sessions = defaultdict(lambda: {
        "tool_calls": 0,
        "response_bytes": 0,
        "read_bytes": 0,
        "reads": 0,
        "delegated_calls": 0,
        "tools": defaultdict(int),
        "repo": None,
        "first": None,
        "last": None,
    })

    session_starts = 0

    for ev in events:
        sid = ev.get("session", "unknown")
        s = sessions[sid]
        s["repo"] = s["repo"] or ev.get("repo")

        ts = ev.get("ts")
        if ts:
            s["first"] = min(s["first"], ts) if s["first"] else ts
            s["last"] = max(s["last"], ts) if s["last"] else ts

        tool = ev.get("tool", "unknown")

        if tool == SESSION_MARKER:
            if ev.get("event") == "SessionStart":
                session_starts += 1
            continue

        s["tool_calls"] += 1
        s["tools"][tool] += 1
        s["response_bytes"] += int(ev.get("response_bytes") or 0)

        if tool in ("Read", "Glob", "Grep"):
            s["reads"] += 1
            s["read_bytes"] += int(ev.get("response_bytes") or 0)

        # Any call whose agent_type is not "main" happened inside a subagent,
        # i.e. its context cost was paid in an isolated window.
        if ev.get("agent_type", "main") != "main":
            s["delegated_calls"] += 1

    # Drop sessions with no real tool calls (session markers only).
    real = {k: v for k, v in sessions.items() if v["tool_calls"] > 0}
    if not real:
        return None

    per_session_bytes = [v["response_bytes"] for v in real.values()]
    per_session_calls = [v["tool_calls"] for v in real.values()]

    total_calls = sum(per_session_calls)
    total_bytes = sum(per_session_bytes)
    delegated = sum(v["delegated_calls"] for v in real.values())

    tool_totals = defaultdict(int)
    tool_bytes = defaultdict(int)
    for v in real.values():
        for t, n in v["tools"].items():
            tool_totals[t] += n
    for ev in events:
        if ev.get("tool") != SESSION_MARKER:
            tool_bytes[ev.get("tool", "unknown")] += int(ev.get("response_bytes") or 0)

    return {
        "sessions": len(real),
        "session_starts": session_starts,
        "total_tool_calls": total_calls,
        "total_response_bytes": total_bytes,
        "median_bytes_per_session": int(statistics.median(per_session_bytes)),
        "mean_bytes_per_session": int(statistics.mean(per_session_bytes)),
        "median_calls_per_session": int(statistics.median(per_session_calls)),
        "bytes_per_tool_call": int(total_bytes / total_calls) if total_calls else 0,
        "delegation_share": (delegated / total_calls) if total_calls else 0.0,
        "repos": sorted({v["repo"] for v in real.values() if v["repo"]}),
        "top_tools": sorted(tool_totals.items(), key=lambda x: -x[1])[:8],
        "top_tools_by_bytes": sorted(tool_bytes.items(), key=lambda x: -x[1])[:8],
    }


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

def human_bytes(n):
    for unit in ("B", "KB", "MB", "GB"):
        if abs(n) < 1024:
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} TB"


def print_block(title, s):
    print(f"\n{title}")
    print("-" * len(title))
    print(f"  Sessions analysed        {s['sessions']}")
    print(f"  Repos                    {', '.join(s['repos']) or 'n/a'}")
    print(f"  Total tool calls         {s['total_tool_calls']:,}")
    print(f"  Total context volume     {human_bytes(s['total_response_bytes'])}")
    print()
    print(f"  Median per session       {human_bytes(s['median_bytes_per_session'])}"
          f"  ({s['median_calls_per_session']} tool calls)")
    print(f"  Mean per session         {human_bytes(s['mean_bytes_per_session'])}")
    print(f"  Per tool call            {human_bytes(s['bytes_per_tool_call'])}")
    print(f"  Delegated to subagents   {s['delegation_share'] * 100:.1f}% of calls")
    print()
    print("  Most-used tools:")
    for tool, count in s["top_tools"]:
        print(f"    {tool:<24} {count:>6,} calls")
    print()
    print("  Heaviest tools by context volume:")
    for tool, b in s["top_tools_by_bytes"]:
        print(f"    {tool:<24} {human_bytes(b):>12}")


def print_delta(before, after):
    print("\nBEFORE vs AFTER")
    print("-" * 15)

    rows = [
        ("Median context per session", "median_bytes_per_session", human_bytes, True),
        ("Mean context per session", "mean_bytes_per_session", human_bytes, True),
        ("Context per tool call", "bytes_per_tool_call", human_bytes, True),
        ("Median tool calls / session", "median_calls_per_session", str, True),
    ]

    for label, key, fmt, lower_is_better in rows:
        b, a = before[key], after[key]
        if b == 0:
            continue
        pct = (a - b) / b * 100
        arrow = "improved" if (pct < 0) == lower_is_better and pct != 0 else "worse"
        if abs(pct) < 1:
            arrow = "flat"
        print(f"  {label:<30} {fmt(b):>12}  ->  {fmt(a):>12}   "
              f"{pct:+6.1f}%  {arrow}")

    b_del = before["delegation_share"] * 100
    a_del = after["delegation_share"] * 100
    print(f"  {'Subagent delegation share':<30} {b_del:>11.1f}%  ->  {a_del:>11.1f}%   "
          f"{a_del - b_del:+6.1f} pts")

    print()
    print("  Sample sizes: "
          f"{before['sessions']} sessions before, {after['sessions']} after.")
    if min(before["sessions"], after["sessions"]) < 20:
        print("  WARNING: fewer than 20 sessions on one side. Treat this as")
        print("           directional only -- do not quote a percentage from it.")


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--log-dir",
                    default=os.environ.get("CLAUDE_USAGE_LOG_DIR",
                                           str(Path.home() / ".claude" / "usage-logs")))
    ap.add_argument("--before", metavar="YYYY-MM-DD",
                    help="Split date. Events before this are the baseline, "
                         "events on/after are the treatment period.")
    ap.add_argument("--json", action="store_true",
                    help="Emit JSON instead of a formatted report.")
    args = ap.parse_args()

    log_dir = Path(args.log_dir).expanduser()
    events = load_events(log_dir)
    if not events:
        sys.exit(f"No events found in {log_dir}.")

    print(f"Claude Code usage report")
    print(f"Source: {log_dir}  ({len(events):,} events)")

    if args.before:
        try:
            split = datetime.strptime(args.before, "%Y-%m-%d").date()
        except ValueError:
            sys.exit("--before must be YYYY-MM-DD")

        before_ev = [e for e in events if (d := event_date(e)) and d < split]
        after_ev = [e for e in events if (d := event_date(e)) and d >= split]

        before, after = summarise(before_ev), summarise(after_ev)
        if not before or not after:
            sys.exit(f"Not enough data on one side of {split}. "
                     f"Baseline events: {len(before_ev)}, after: {len(after_ev)}")

        if args.json:
            print(json.dumps({"before": before, "after": after}, default=str, indent=2))
            return

        print_block(f"BASELINE (before {split})", before)
        print_block(f"AFTER ({split} onward)", after)
        print_delta(before, after)
    else:
        s = summarise(events)
        if not s:
            sys.exit("No tool-call events found -- only session markers.")
        if args.json:
            print(json.dumps(s, default=str, indent=2))
            return
        print_block("ALL LOGGED ACTIVITY", s)

    print()
    print("Reminder: 'context volume' is bytes of tool output entering the")
    print("context window. It is a proxy, not a token count. See")
    print("docs/MEASUREMENT.md before putting any of these numbers in a deck.")
    print()


if __name__ == "__main__":
    main()
