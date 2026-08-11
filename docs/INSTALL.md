# Install

Full step-by-step walkthrough, about 5 minutes. For the pitch and the
post-install workflow, see the [README](../README.md).

---

## Prerequisites

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

## Step 1 — Clone ContextLens

```bash
git clone https://github.com/VedMungra/ContextLens.git /tmp/contextlens
```

This is a temporary copy you install *from*. It is not where you work.

---

## Step 2 — Go to your own repo

```bash
cd /path/to/your/repo        # Windows: cd "/d/Your Project"
git status                   # confirm you're in the right place
git checkout -b contextlens  # work on a branch, not main
```

**Which repo?** One you'll actively code in for the next month. A finished
project generates no sessions, so there'd be nothing to measure.

---

## Step 3 — Copy the files in

```bash
cp -r /tmp/contextlens/.claude .
cp -r /tmp/contextlens/scripts .
mkdir -p docs && cp -r /tmp/contextlens/docs/* docs/
chmod +x .claude/hooks/*.sh
```

### 🪟 Windows: two extra commands

The default config uses a form that requires a real executable, and `.sh`
files aren't executables on Windows — so the hooks would silently never fire.
Swap in the Windows config:

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

## Step 4 — Hold back the agents and commands ⚠️

**Do not skip this.** It's what makes your final number mean anything.

```bash
mkdir -p /tmp/contextlens-hold
mv .claude/agents .claude/commands /tmp/contextlens-hold/
```

You'll move them back in two weeks. `/tmp` gets cleared on reboot on some
systems — if that worries you, use a folder in your home directory instead.

---

## Step 5 — Verify it works

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

Or, faster — run the doctor, which checks all of the above in one pass:

```bash
bash scripts/doctor.sh
```

**Empty log, or a FAIL from the doctor?** → [Troubleshooting](#troubleshooting).

---

## Step 6 — Commit, and write down the date

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

Restart Claude Code. `/scout`, `/review`, and `/context` are now available —
see the [README](../README.md#the-two-week-cycle) for what each one does.

---

## Troubleshooting

### Run the doctor first

`report.py` can't tell "nobody has used Claude Code yet" from "the hooks
broke two weeks ago" — an empty log directory looks the same either way.
Before working through the manual steps below, run:

```bash
bash scripts/doctor.sh
```

It prints PASS/FAIL for the usual causes — jq missing, hooks not executable,
CRLF line endings, an invalid or wrong-platform `settings.json`, and a live
end-to-end run of `log-usage.sh` — so you know which section below to read
instead of checking all of them by hand.

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

- They're held back during your baseline — that's Step 4 working as intended
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
