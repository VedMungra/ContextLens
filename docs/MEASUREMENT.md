# Measurement

Read this before quoting any number from this kit.

---

## What is measured

Every tool call appends one line to a daily JSONL log:

| Field | Meaning |
|---|---|
| `tool` | Which tool was called (`Read`, `Grep`, `Edit`, `Bash`, …) |
| `response_bytes` | Size of the tool's result, i.e. the material that entered the context window |
| `input_bytes` | Size of the tool's arguments |
| `agent_type` | `main`, or the subagent name if the call happened inside one |
| `session` | Session identifier, for per-session aggregation |
| `repo` | Repository basename |
| `file` | Basename only, never the full path or contents |

`report.py` aggregates these into:

- **Median context volume per session** — the headline metric
- **Median turn-weighted volume per session** — a second headline metric, see
  below
- **Context volume per tool call** — catches "fewer, bigger reads"
- **Median tool calls per session**
- **Delegation share** — percentage of calls made inside subagents

---

## What `response_bytes` is not

It is **not a token count.** Bytes and tokens correlate but the ratio varies
by content: minified JSON, dense code, and prose tokenize differently.

It is **not a bill.** It ignores cached prefix reuse, output tokens, and the
fact that context is re-sent on every request within a session — which means
the raw byte total *understates* the real effect of trimming context. See
"Turn-weighted volume" below for the metric that corrects for this.

It is **a proxy for context volume**, and context volume is the thing our
changes actually move. That makes it the right instrument for "did this work",
and the wrong instrument for "what did we save in rupees".

### Turn-weighted volume

`response_bytes` treats a 100 KB tool result loaded on turn 1 of a 21-turn
session the same as an identical 100 KB result loaded on the last turn. That's
wrong: Claude Code resends the full conversation context on every turn, so
the turn-1 load is re-billed 21 times over and the last-turn load is billed
once. **Raw context volume understates the cost of early loads** — sometimes
by an order of magnitude — and it makes early-session context hygiene look
less valuable than it is.

`report.py` corrects for this with a second headline metric,
`weighted_bytes`. For each session it:

1. Groups that session's tool-call events by `prompt_id`, in order of first
   appearance, to assign each call a turn ordinal (1 = first turn).
2. Computes, per call: `weighted_bytes = response_bytes * (total_turns -
   turn_ordinal + 1)` — i.e. the number of turns (including the current one)
   that the load's bytes were still sitting in context and being re-sent.
3. Sums across the session.

A call on turn 1 of a 21-turn session is weighted ×21. The same call on turn
21 is weighted ×1. This is still a proxy — it assumes every turn resends the
full prior context, which is directionally true but ignores compaction and
prompt caching — but it is a much closer approximation of what an early,
avoidable load actually costs than the raw byte count is.

Both metrics are reported side by side, and both appear in the before/after
delta table. Keep using raw volume for "how much stuff came back"; use
turn-weighted volume for "how much did loading it early actually cost".

### When you need real numbers

Claude Code supports OpenTelemetry metrics export, which reports actual token
counts and cost. Use that if finance wants a figure. It runs alongside this
kit without conflict. This kit exists because it installs in five minutes and
needs no collector infrastructure.

---

## Running a defensible baseline

The whole exercise depends on week 1 being untouched. Specifically:

1. **Install hooks only.** No `CLAUDE.md`, no agents, no commands. If any
   part of the kit is live during the baseline, the comparison is meaningless.
2. **Change nothing about how people work.** Do not announce "we are
   measuring efficiency" in a way that makes people self-consciously optimise.
   Say the hooks are for usage visibility, which is true.
3. **Collect at least 20 sessions per side.** Below that, session-to-session
   variance swamps the effect. `report.py` prints a warning under this
   threshold — take the warning seriously.
4. **Record the split date.** Write it down. You will need it in three months
   and you will not remember it.

```bash
# End of week 4
python3 scripts/report.py --before 2026-09-01
python3 scripts/report.py --before 2026-09-01 --json > results/week4.json
```

**Keep the JSON.** Commit `results/*.json` alongside the split date and a note
on what changed between periods. This archive is what lets you answer "how did
you measure that?" months later, when your memory of the setup is gone.

---

## Confounders you must disclose

A percentage without these caveats is not honest:

- **Task mix changed.** If the baseline period was feature work and the
  treatment period was bug fixes, the difference may be the work, not the kit.
  Note what each period contained.
- **Team size changed.** New joiners have different usage patterns.
- **Novelty effect.** People use a new tool carefully in week one. Re-measure
  at week eight to see what survives.
- **Selection.** If only enthusiastic adopters installed the kit, you are
  measuring enthusiasm as much as configuration.

None of these invalidate the result. Stating them alongside the number makes
it stronger, not weaker — it demonstrates you understood what you were
measuring.

---

## Claiming this on a CV or in an interview

The defensible form names the metric, the method, and the sample:

> "Median context volume per session fell from 297 KB to 87 KB (−71%) across
> 84 sessions before and 84 after, measured via tool-call instrumentation over
> four weeks. Context volume is a byte-level proxy for tokens, not a billing
> figure."

The indefensible form is a bare percentage with no method behind it. An
interviewer's next question is always "measured how?", and "I estimated it"
costs more credibility than the number ever bought.

If the numbers come out flat or worse, report that. A negative result you
measured properly is a better story than a positive one you cannot explain —
and it is genuinely more useful to the team.
