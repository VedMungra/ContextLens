# ContextLens

**Measure and reduce Claude Code context usage.**

Claude Code bills on tokens. The biggest thing you control is how much material
gets pulled into the context window — and re-sent on every single turn after
that. Most people optimise this by feel. ContextLens measures it first, then
gives you three levers to act on what you find.

Install: about 5 minutes.

---

> ### ⚠️ Read this before you install
>
> **Turn on the logging first. Add everything else two weeks later.**
>
> The whole point is a before/after comparison. If you install the agents and
> commands on day one, there is no "before" — and you cannot go back and
> collect it later.
>
> The install steps below hold back the right pieces automatically. Don't skip
> Step 5.

---

## What you get

**Measurement** — a hook records metadata for every tool call (which tool, how
many bytes came back, which subagent). A report script turns weeks of that into
a before/after number.

**Reduction** — a cheap-model search agent keeps file contents out of your main
context. A `/context` command tells you what to drop mid-session. A `CLAUDE.md`
template stops Claude guessing at your build commands.

**A guardrail** — an optional hook blocks reads and writes to `.env`, `*.pem`,
credentials, and similar.

**No source code, no prompts, and no file contents are ever logged.** Nothing
leaves your machine. See [Privacy](#privacy).

---

## Step 1 — Check what you have

Run these three. Every one needs to work before you continue.

```bash
claude --version    # Claude Code
jq --version        # JSON processor — hooks silently do nothing without it
git --version       # Git
```

### Installing what's missing

**Claude Code** (needs Node.js 18+):

```bash
node --version    # if missing, install Node first
npm install -g @anthropic-ai/claude-code
```

**jq:**

| OS | Command |
|---|---|
| macOS | `brew install jq` |
| Ubuntu / Debian | `sudo apt-get install -y jq` |
| Windows | `winget install jqlang.jq` (in PowerShell) |

### 🪟 Windows: use Git Bash

The hooks are shell scripts. **They will not run in PowerShell or CMD.**

```
winget install Git.Git
```

Then open **Git Bash** from the Start menu and run everything below there.

Two things look different in Git Bash: `D:\my-repo` is written `/d/my-repo`,
and paths with spaces need quotes — `cd "/d/My Project"`.

After installing anything with `winget`, **close and reopen Git Bash** so the
PATH refreshes.

---

## Step 2 — Clone ContextLens

```bash
git clone https://github.com/VedMungra/ContextLens.git /tmp/contextlens
```

This is a temporary copy you install *from*. It is not where you work.

---

## Step 3 — Go to your own repo

```bash
cd /path/to/your/repo        # Windows: cd "/d/Your Project"
git status                   # confirm you're in the right place
git checkout -b contextlens  # work on a branch, not main
```

**Which repo?** One you'll actively code in for the next month. A finished
project generates no sessions, so there'd be nothing to measure.

---

## Step 4 — Copy the files in

```bash
cp -r /tmp/contextlens/.claude .
cp -r /tmp/contextlens/scripts .
mkdir -p docs && cp -r /tmp/contextlens/docs/* docs/
chmod +x .claude/hooks/*.sh
```

### 🪟 Windows: two extra commands

The default config uses a form that requires a real executable, and `.sh` files
aren't executables on Windows — so the hooks would silently never fire. Swap in
the Windows config:

```bash
cp .claude/settings-windows.json .claude/settings.json
grep -c '"shell": "bash"' .claude/settings.json
```

**That must print `4`.** If it prints `0`, the swap didn't work — stop and fix
it, or nothing below will function.

Then protect the line endings, or Bash will choke on `\r`:

```bash
printf '*.sh text eol=lf\n' >> .gitattributes
file .claude/hooks/*.sh      # must NOT mention "CRLF"
```

If it does mention CRLF:

```bash
sed -i 's/\r$//' .claude/hooks/*.sh
```

---

## Step 5 — Hold back the agents and commands ⚠️

**Do not skip this.** It's what makes your final number mean anything.

```bash
mkdir -p /tmp/contextlens-hold
mv .claude/agents .claude/commands /tmp/contextlens-hold/
```

You'll move them back in two weeks. `/tmp` gets cleared on reboot on some
systems — if that worries you, use a folder in your home directory instead.

---

## Step 6 — Verify it works

Start Claude Code in your repo:

```bash
claude
```

Type `/hooks`. You should see **PreToolUse**, **PostToolUse**, **SessionStart**,
and **SessionEnd** with counts next to them. (The menu lists every possible
event — only the ones showing a count are yours.)

Now ask Claude something that makes it touch a file:

```
what files are in this project?
```

Exit with `/exit`, then check the log:

```bash
cat ~/.claude/usage-logs/$(date -u +%Y-%m-%d).jsonl
```

You want lines like this:

```json
{"ts":"2026-08-11T09:15:22Z","repo":"my-project","session":"dbb5a2de-...",
 "tool":"Read","agent_type":"main","response_bytes":6475,"file":"index.js"}
```

**Empty or missing?** → [Troubleshooting](#troubleshooting).

---

## Step 7 — Commit, and write down the date

```bash
git add .claude scripts docs .gitattributes
git commit -m "Add ContextLens instrumentation"
```

📅 **Write down today's date.** You need it in two weeks for
`report.py --before <date>`. You will not remember it otherwise.

---

## Then: use Claude Code normally for two weeks

Change nothing. Don't optimise, don't add `CLAUDE.md`, don't restore the
agents. You're collecting the "before" picture, and self-consciously
optimising during it defeats the purpose.

Check progress any time:

```bash
python3 scripts/report.py
```

---

## After two weeks — turn everything on

```bash
mv /tmp/contextlens-hold/agents /tmp/contextlens-hold/commands .claude/
cp /tmp/contextlens/templates/CLAUDE.md.template ./CLAUDE.md
```

Now fill in `CLAUDE.md` for your repo: build and test commands, architecture in
ten lines, conventions that aren't obvious from the code, things not to touch.

**Keep it under ~150 lines.** It loads on every session, and it sits in the
cached prefix — so frequent edits also cost you prompt-cache hits.

Restart Claude Code. Three commands are now available:

| Command | What it does |
|---|---|
| `/scout <target>` | Delegates code search to a cheap Haiku subagent that returns `file:line` maps instead of dumping file contents into your context |
| `/review` | Read-only review of your current diff, checked against your `CLAUDE.md` |
| `/context` | Audits what's loaded in this session and tells you what to drop |

Use them for another two weeks.

---

## Getting your number

```bash
python3 scripts/report.py --before 2026-08-25    # your split date
python3 scripts/report.py --before 2026-08-25 --json > results.json
```

Sample output:

```
BEFORE vs AFTER
  Median context per session    296.9 KB  ->   86.5 KB   -70.9%  improved
  Context per tool call           8.9 KB  ->    4.1 KB   -54.0%  improved
  Subagent delegation share          2.1% ->     32.2%   +30.1 pts

  Sample sizes: 84 sessions before, 84 after.
```

**Keep `results.json`.** Commit it with the split date. In three months you
won't remember how you measured this, and that file is the difference between a
number you can explain and one you can't.

### What the number actually means

The metric is **context volume**: bytes of tool output entering the context
window.

It is **not a token count** and **not a bill.** Bytes and tokens correlate
imperfectly, and this ignores cached prefix reuse and output tokens. It is a
solid proxy for judging whether a change helped, and the wrong instrument for
telling finance what you saved.

For real token and cost figures, Claude Code supports OpenTelemetry export.
That runs alongside this without conflict. ContextLens exists because it
installs in five minutes and needs no collector.

**Below ~20 sessions per side, don't quote a percentage** — session variance
swamps the effect. The report warns you when you're under.

`docs/MEASUREMENT.md` covers the confounders worth disclosing: task mix,
novelty effect, team composition, selection.

---

## Troubleshooting

### The log file is empty or doesn't exist

Work through these in order — it's almost always one of the first three.

**1. jq isn't installed**

```bash
jq --version
```

The hooks fail silently by design (a broken measurement tool must never block
your work), so a missing `jq` looks exactly like nothing happening.

**2. Hooks aren't executable**

```bash
ls -l .claude/hooks/
```

You want `-rwxr-xr-x`. If you see `-rw-r--r--`:

```bash
chmod +x .claude/hooks/*.sh
```

**3. 🪟 Wrong settings file on Windows**

```bash
grep -c '"shell": "bash"' .claude/settings.json
```

Must print `4`. If it prints `0`:

```bash
cp .claude/settings-windows.json .claude/settings.json
```

**4. 🪟 Windows line endings**

```bash
file .claude/hooks/*.sh
```

If any say "CRLF":

```bash
sed -i 's/\r$//' .claude/hooks/*.sh
```

**5. Started Claude Code from the wrong directory**

Hooks resolve paths via `${CLAUDE_PROJECT_DIR}`. Launch `claude` from your repo
root.

**6. Still nothing — get the actual error**

```bash
claude --debug-file /tmp/cc.log
# reproduce the problem, exit, then:
grep -i hook /tmp/cc.log
```

### Test a hook directly

Bypasses Claude Code entirely, so you learn whether the script itself works:

```bash
export CLAUDE_USAGE_LOG_DIR=/tmp/hooktest
printf '%s' '{"session_id":"t1","hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"/x/a.py"},"tool_response":"hello"}' | bash .claude/hooks/log-usage.sh
cat /tmp/hooktest/*.jsonl
```

A JSON line with `"response_bytes":5` means the script is fine and the problem
is in the wiring. Nothing means it's `jq` or line endings.

### `/hooks` shows nothing configured

- Restart Claude Code — config loads at session start
- Confirm `.claude/settings.json` exists at your repo root
- Validate the JSON: `python3 -c "import json;json.load(open('.claude/settings.json'))"`

### `/scout` or `/review` aren't offered

- They're held back during your baseline — that's Step 5 working as intended
- After restoring them, restart Claude Code
- Confirm `.claude/agents/` and `.claude/commands/` are at the repo root

### The secrets guard is blocking a file I need

Edit `BLOCKED_PATTERNS` in `.claude/hooks/guard-secrets.sh`, or remove the
`PreToolUse` block from `.claude/settings.json` entirely.

### `python3: command not found`

Try `python` instead. On Windows, `python3` often isn't aliased.

### `bash: syntax error near unexpected token`

You pasted terminal output (including the `$` prompt) back into the terminal.
Copy only the commands, and run them one line at a time.

---

## Privacy

**Recorded per tool call:** timestamp, repo folder name, session and prompt IDs,
tool name, subagent name, byte counts, and the file's *basename* (`login.js`,
never the full path).

**Never recorded:** file contents, source code, your prompts, Claude's replies,
full paths, shell command text, environment variables, credentials.

Everything stays in `~/.claude/usage-logs/` on your machine. There is no server
and nothing is transmitted anywhere.

A complete log line, in full:

```json
{"ts":"2026-08-11T09:15:22Z","repo":"my-project","session":"abc123",
 "prompt_id":"p-1","tool":"Read","agent_type":"main",
 "response_bytes":6475,"input_bytes":188,"file":"login.js"}
```

**To opt out:** delete the `PostToolUse` block from `.claude/settings.json`.
Everything else keeps working.

Rolling this out to a team? `docs/PRIVACY.md` is written to be forwarded to
whoever needs to approve it.

---

## What's in the box

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
templates/                 CLAUDE.md template
docs/
  INSTALL.md               Setup detail
  MEASUREMENT.md           Methodology and confounders
  PRIVACY.md               Forward this for approval
  ROLLOUT.md               Four-week team plan
```

---

## Rolling out to a team

`docs/ROLLOUT.md` has a four-week plan with decision points. The short version:

1. **Get privacy approval first.** Forward `docs/PRIVACY.md`. Doing this in
   week 3 instead of week 0 is how these projects die.
2. **Week 1:** hooks only, everyone. Baseline.
3. **Week 2:** `CLAUDE.md`, reviewed on a PR by people who know the code.
4. **Week 3:** agents and commands, introduced with a live demo — not a doc.
5. **Week 4:** run the report, circulate it, decide.

Open it as a PR rather than pushing to main. Someone should review code that's
going to run on everyone's machine, and the merge is your record of adoption.

---

## Status

Hook scripts and `report.py` are tested against representative payloads: normal
tool calls, subagent calls, nested-object responses, missing fields, and
malformed input. Hooks fail silently by design.

Verified end to end on Windows with Git Bash, including a fresh-clone install.
Not yet exercised at team scale — issues and corrections welcome.
