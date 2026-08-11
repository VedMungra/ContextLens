# ContextLens

**Measure and reduce Claude Code context usage.**

Claude Code bills on tokens. The biggest thing you control is how much material
gets pulled into the context window — and re-sent on every single turn after
that. Most people optimise this by feel. ContextLens measures it first, then
gives you three levers to act on what you find.

Install: about 5 minutes, full walkthrough in [docs/INSTALL.md](docs/INSTALL.md).

---

> ### ⚠️ Read this before you install
>
> **Turn on the logging first. Add everything else two weeks later.**
>
> The whole point is a before/after comparison. If you install the agents and
> commands on day one, there is no "before" — and you cannot go back and
> collect it later. [docs/INSTALL.md](docs/INSTALL.md) holds back the right
> pieces automatically — don't skip that step.

---

## What you get

- **Measurement** — a hook logs metadata for every tool call (which tool, how
  many bytes came back, which subagent). A report script turns weeks of that
  into a before/after number.
- **Reduction** — a cheap-model search agent keeps file contents out of your
  main context, a `/context` command tells you what to drop mid-session, and
  a `CLAUDE.md` template stops Claude guessing at your build commands.
- **A guardrail** — an optional hook blocks reads, writes, greps, and shell
  access to `.env`, `*.pem`, credentials, and similar.
- **Nothing leaves your machine** — no source code, prompts, or file contents
  are ever logged. See [Privacy](#privacy).

---

## Quickstart

🪟 **On Windows**, hooks need Git Bash, and `.claude/settings.json` needs
swapping for the Windows variant *before* you run the block below — see
[docs/INSTALL.md](docs/INSTALL.md), or `doctor.sh` will just tell you it's
broken without saying why.

```bash
git clone https://github.com/VedMungra/ContextLens.git /tmp/contextlens
cd /path/to/your/repo && git checkout -b contextlens
cp -r /tmp/contextlens/.claude /tmp/contextlens/scripts .
mkdir -p docs && cp -r /tmp/contextlens/docs/* docs/
chmod +x .claude/hooks/*.sh

# hold back the pieces that would contaminate your baseline
mkdir -p /tmp/contextlens-hold
mv .claude/agents .claude/commands /tmp/contextlens-hold/

bash scripts/doctor.sh   # confirms the install actually works

git add .claude scripts docs
git commit -m "Add ContextLens instrumentation"
# 📅 write down today's date -- you need it in two weeks for report.py --before
```

Full command-by-command walkthrough, verification steps, and the reasoning
behind each one: **[docs/INSTALL.md](docs/INSTALL.md)**.

---

## The two-week cycle

Use Claude Code normally for two weeks with just the hooks installed — no
`CLAUDE.md`, agents still held back, no self-conscious optimising. Then:

```bash
mv /tmp/contextlens-hold/agents /tmp/contextlens-hold/commands .claude/
cp /tmp/contextlens/templates/CLAUDE.md.template ./CLAUDE.md   # fill in, keep under ~150 lines
```

Three commands become available:

| Command | What it does |
|---|---|
| `/scout <target>` | Delegates code search to a cheap Haiku subagent that returns `file:line` maps instead of dumping file contents into your context |
| `/review` | Read-only review of your current diff, checked against your `CLAUDE.md` |
| `/context` | Audits what's loaded in this session and tells you what to drop |

Use them for another two weeks, then get your number.

---

## Getting your number

```bash
python3 scripts/report.py --before 2026-08-25    # your split date
mkdir -p results
python3 scripts/report.py --before 2026-08-25 --json > results/2026-08-25.json
```

```
BEFORE vs AFTER
  Median context per session    296.9 KB  ->   86.5 KB   -70.9%  improved
  Context per tool call           8.9 KB  ->    4.1 KB   -54.0%  improved
  Subagent delegation share          2.1% ->     32.2%   +30.1 pts

  Sample sizes: 84 sessions before, 84 after.
```

`response_bytes` is a **proxy for context volume — not a token count and not a
bill.** [docs/MEASUREMENT.md](docs/MEASUREMENT.md) covers what it does and
doesn't support, the turn-weighted metric that corrects for early-session
loads being re-sent on every turn, and the confounders worth disclosing (task
mix, novelty effect, team composition, selection).

**Below ~20 sessions per side, don't quote a percentage** — session variance
swamps the effect, and the report warns you when you're under.

**Keep `results/*.json`, committed with the split date.** In three months you
won't remember how you measured this, and that file is the difference between
a number you can explain and one you can't.

---

## Troubleshooting

Run the doctor first:

```bash
bash scripts/doctor.sh
```

It prints PASS/FAIL for the usual causes — jq missing, hooks not executable,
CRLF line endings, an invalid or wrong-platform `settings.json`, and a live
end-to-end run of `log-usage.sh`. For the full manual checklist — empty log
file, `/scout` not offered, the secrets guard blocking something legitimate,
and more — see **[docs/INSTALL.md § Troubleshooting](docs/INSTALL.md#troubleshooting)**.

---

## Privacy

**Recorded per tool call:** timestamp, repo folder name, session and prompt IDs,
tool name, subagent name, byte counts, and the file's *basename* (`login.js`,
never the full path).

**Never recorded:** file contents, source code, your prompts, Claude's replies,
full paths, shell command text, environment variables, credentials.

Everything stays in `~/.claude/usage-logs/` on your machine. There is no server
and nothing is transmitted anywhere. **To opt out:** delete the `PostToolUse`
block from `.claude/settings.json` — everything else keeps working.

Rolling this out to a team? [docs/PRIVACY.md](docs/PRIVACY.md) is written to be
forwarded to whoever needs to approve it, and includes a complete sample log
line.

---

<details>
<summary><h2 style="display:inline">What's in the box</h2></summary>

```
.claude/
  settings.json            Hook wiring — macOS / Linux
  settings-windows.json    Hook wiring — Windows / Git Bash
  hooks/
    log-usage.sh           One metadata line per tool call
    log-session.sh         Session boundary markers
    guard-secrets.sh       Blocks secret-bearing paths
  agents/
    scout.md               Haiku search agent
    reviewer.md            Read-only diff reviewer
  commands/                /scout, /review, /context

scripts/report.py          Log aggregation, before/after report
scripts/doctor.sh          PASS/FAIL checks for a broken install
templates/                 CLAUDE.md template
docs/
  INSTALL.md               Full setup walkthrough + troubleshooting
  MEASUREMENT.md           Methodology, turn-weighted metric, confounders
  PRIVACY.md               Forward this for approval
  ROLLOUT.md               Four-week team plan
```

</details>

<details>
<summary><h2 style="display:inline">Rolling out to a team</h2></summary>

[docs/ROLLOUT.md](docs/ROLLOUT.md) has a four-week plan with decision points.
The short version:

1. **Get privacy approval first.** Forward `docs/PRIVACY.md`. Doing this in
   week 3 instead of week 0 is how these projects die.
2. **Week 1:** hooks only, everyone. Baseline.
3. **Week 2:** `CLAUDE.md`, reviewed on a PR by people who know the code.
4. **Week 3:** agents and commands, introduced with a live demo — not a doc.
5. **Week 4:** run the report, circulate it, decide.

Open it as a PR rather than pushing to main. Someone should review code that's
going to run on everyone's machine, and the merge is your record of adoption.

</details>

<details>
<summary><h2 style="display:inline">Status</h2></summary>

Hook scripts and `report.py` are tested against representative payloads: normal
tool calls, subagent calls, nested-object responses, missing fields, and
non-ASCII or malformed input. The secrets guard fails closed; logging fails
silent by design, so a broken measurement tool never blocks your work.

Verified end to end on Windows with Git Bash, including a fresh-clone install.
Not yet exercised at team scale — issues and corrections welcome.

</details>
