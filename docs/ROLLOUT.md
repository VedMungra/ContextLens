# Rollout

Four weeks, one change per week, with a decision point at the end of each.
The sequence matters more than the speed: measuring before changing anything
is what makes the final number mean something.

---

## Before week 1 — get approval

Two decisions need someone with authority:

- **Privacy.** Walk through `PRIVACY.md`. Confirm the logging is acceptable
  and decide whether logs stay local or get aggregated for a team report.
- **Secrets guard.** Confirm the blocked-path patterns match our repo layout,
  or drop the guard entirely.

Get one named person who wants this to exist. A configuration kit with no
sponsor gets merged and forgotten. The sponsor is who you show the week-4
report to, and who tells the team it matters.

---

## Week 1 — baseline

**Ship:** hooks only. `.claude/settings.json`, `.claude/hooks/`.

**Do not ship:** `CLAUDE.md`, agents, or commands. Anything live during the
baseline period contaminates the comparison.

**Announce it as:** usage visibility. That is accurate and it avoids the
observer effect you get from announcing an efficiency measurement.

**Check on day 2:** confirm logs are actually being written on more than one
machine. A silent `jq` or `chmod` failure discovered in week 4 costs the whole
baseline. Ask two colleagues to run `ls ~/.claude/usage-logs/` and report back.

**Decision point:** are logs landing for at least four engineers? If not, fix
installation before proceeding. Everything downstream depends on this working.

---

## Week 2 — CLAUDE.md

**Ship:** a filled-in `CLAUDE.md` at the root of the main repo.

Do not write it alone. Draft it from the template, then have two engineers who
know the repo review it on a PR. Their corrections are the actual content —
your draft is a prompt for their knowledge.

Keep it under 150 lines. Every line is paid for on every session.

**Decision point:** did anyone object to a convention you documented? A
disagreement here is valuable — it means the convention was never actually
shared, and the file just surfaced it.

---

## Week 3 — agents and commands

**Ship:** `scout`, `reviewer`, `/scout`, `/review`, `/context`.

**Introduce it in ten minutes at standup.** Demonstrate `/scout` on a real
question in a real repo. Do not send a document; nobody reads tooling docs.
One live demo where the thing visibly works is worth more than a wiki page.

Make one specific ask: "next time you need to find where something lives,
type `/scout` instead of asking directly." A single concrete habit is
adoptable. "Use these five features" is not.

**Decision point:** check the delegation share mid-week:

```bash
python3 scripts/report.py | grep -i delegat
```

If it is near zero, people are not using scout. That is a communication
problem, not a technical one — and the fix is usually adding the delegation
paragraph to `CLAUDE.md`, which makes the main model reach for scout on its
own instead of waiting to be told.

---

## Week 4 — report and decide

```bash
python3 scripts/report.py --before <week-3-start-date>
python3 scripts/report.py --before <week-3-start-date> --json > results/week4.json
```

Commit `results/week4.json` and the split date.

**Circulate a short summary**, not the raw output. Lead with what changed,
state the sample size, name the confounders from `MEASUREMENT.md` that apply.

**Decision point:** three honest outcomes, all of them fine.

- **Clear improvement** → extend to a second repo, keep measuring.
- **Flat** → say so. Then look at the per-tool breakdown to find where context
  volume actually concentrates; the answer is often one specific file or one
  specific habit, and that is a more targeted fix than the kit.
- **Worse** → also say so, and find out why. The most common cause is a
  `CLAUDE.md` that grew too long and now costs more than it saves.

Reporting a flat or negative result accurately is the thing that makes your
positive results believable later.

---

## Failure modes, in order of likelihood

**Nobody uses it.** The most common outcome for internal tooling. Counter it
with a live demo, a single concrete habit to adopt, and a sponsor who mentions
it. Adoption is the metric that matters — a technically excellent kit with
three users has failed.

**Installed but not measured.** Someone skips week 1, ships everything at
once, and there is no baseline. Unrecoverable. Hold the line on the sequence.

**CLAUDE.md bloat.** It starts at 100 lines and reaches 400 by month two as
people append. Then it costs more than it saves and, because it sits in the
cached prefix, frequent edits also break prompt caching. Review it monthly and
cut.

**Security objection in week 3.** Avoided entirely by raising privacy before
week 1. Do not skip that conversation because it seems slow.

**The report goes to nobody.** Numbers nobody sees change nothing. Schedule
the week-4 review with the sponsor at the same time you start week 1.
