# ContextLens

Measure and reduce Claude Code context usage.

Claude Code bills on tokens, and the biggest controllable input is how much
material gets pulled into the context window and re-sent on every turn. Most
teams optimise this by feel. ContextLens measures it first, then gives you
three levers to act on what you find.

Install time: about five minutes.

---

## What it does

**Measures.** A lifecycle hook records structural metadata for every tool call
— which tool, how many bytes came back, which subagent. No source code, no
prompts, no file contents. A report script turns that into before/after
numbers.

**Reduces.** A cheap-model search agent keeps file contents out of your main
context. A `/context` command tells you what to drop mid-session. A
`CLAUDE.md` template stops Claude guessing at your build commands and
conventions.

**Guards.** An optional hook blocks reads and writes to `.env`, `*.pem`,
credentials, and similar.

---

## Requirements

- [Claude Code](https://www.npmjs.com/package/@anthropic-ai/claude-code)
- `jq` — the logging hooks no-op silently without it
- Windows users: **Git Bash**. The hooks are shell scripts and will not run
  under PowerShell alone.

```bash
jq --version
# macOS:    brew install jq
# Ubuntu:   sudo apt-get install -y jq
# Windows:  winget install jqlang.jq   (then use Git Bash)
```

---

## Install

```bash
git clone https://github.com/YOUR-USERNAME/contextlens.git /tmp/contextlens
cd /path/to/your/repo

cp -r /tmp/contextlens/.claude .
cp -r /tmp/contextlens/scripts .
mkdir -p docs && cp -r /tmp/contextlens/docs/* docs/

chmod +x .claude/hooks/*.sh
```

### Windows only

The default `settings.json` uses exec form, which requires a real executable —
a `.sh` file is not one on Windows, so the hooks would silently never fire.
Swap in the shell-form config:

```bash
cp .claude/settings-windows.json .claude/settings.json
grep -c '"shell": "bash"' .claude/settings.json   # must print 4
```

Also protect the line endings, or Bash will fail on `\r`:

```bash
printf '*.sh text eol=lf\n' >> .gitattributes
file .claude/hooks/*.sh    # must NOT say "CRLF"
```

### Verify

Start Claude Code in the repo and type `/hooks` — you should see PostToolUse,
SessionStart, SessionEnd, and PreToolUse configured. Ask Claude to read any
file, then:

```bash
cat ~/.claude/usage-logs/$(date -u +%Y-%m-%d).jsonl
```

Lines containing `"tool"` and `"response_bytes"` mean it works. An empty file
almost always means missing `jq`, a missing `+x` bit, or CRLF line endings.

---

## Use

```bash
python3 scripts/report.py                      # everything logged so far
python3 scripts/report.py --before 2026-09-01  # baseline vs. treatment
python3 scripts/report.py --json               # machine-readable
```

Three commands become available inside Claude Code:

| Command | What it does |
|---|---|
| `/scout <target>` | Delegates code search to a Haiku subagent that returns file:line maps instead of file contents |
| `/review` | Runs a read-only reviewer over the current diff, checked against your `CLAUDE.md` |
| `/context` | Audits what is loaded in the session and recommends what to drop |

Fill in `templates/CLAUDE.md.template` for your repo. Keep it under ~150 lines
— it loads on every session, and it sits in the cached prefix, so frequent
edits also cost you prompt-cache hits.

---

## Getting a number you can defend

The sequence matters more than the speed.

1. **Install hooks only.** Delete or hold back `.claude/agents/` and
   `.claude/commands/` for now. Anything live during the baseline contaminates
   the comparison.
2. **Wait two weeks.** Work normally. Write down the split date.
3. **Then** add `CLAUDE.md`, restore the agents and commands, and use them.
4. **Run the report** with `--before <split date>` and keep the `--json`
   output.

Below roughly 20 sessions per side, session-to-session variance swamps the
effect. The report prints a warning when you are under that.

### What the numbers mean

The metric is **context volume**: bytes of tool output entering the context
window. It is a proxy, and a good one for judging whether a change helped —
but it is **not a token count and not a billing figure**. Bytes and tokens
correlate imperfectly, and this ignores cached prefix reuse and output tokens.

For real token and cost figures, Claude Code supports OpenTelemetry export.
That runs alongside this without conflict. ContextLens exists because it
installs in five minutes and needs no collector infrastructure.

`docs/MEASUREMENT.md` covers the confounders you should disclose alongside any
percentage: task mix, novelty effect, team composition, selection.

---

## Privacy

Logged, per tool call: timestamp, repo basename, session and prompt IDs, tool
name, subagent name, byte counts, and the file's basename.

Not logged: file contents, source code, prompts, Claude's responses, full
paths, shell command text, environment variables.

Everything stays in `~/.claude/usage-logs/` on the local machine. There is no
server and nothing is transmitted. Full detail in `docs/PRIVACY.md`.

To opt out, delete the `PostToolUse` block from `.claude/settings.json`.

---

## Layout

```
.claude/
  settings.json            Hook wiring (exec form — macOS/Linux)
  settings-windows.json    Hook wiring (shell form — Windows/Git Bash)
  hooks/
    log-usage.sh           One metadata line per tool call
    log-session.sh         Session boundary markers
    guard-secrets.sh       Blocks secret-bearing paths
  agents/
    scout.md               Haiku search agent
    reviewer.md            Read-only diff reviewer
  commands/                /scout, /review, /context

scripts/report.py          Log aggregation and before/after report
templates/                 CLAUDE.md template
docs/                      INSTALL, MEASUREMENT, PRIVACY, ROLLOUT
```

---

## Status

Hook scripts and `report.py` are tested against representative payloads:
normal tool calls, subagent calls, nested-object responses, missing fields,
and malformed input. Hooks fail silently by design — a broken measurement tool
must never block someone's work.

Verified end-to-end on Windows with Git Bash. Not yet exercised at team scale;
if you roll it out to more than a handful of people, issues and corrections are
welcome.
