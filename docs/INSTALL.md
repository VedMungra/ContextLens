# Install (about five minutes)

## Prerequisites

- Claude Code, already working
- `jq` — the logging hooks no-op without it

```bash
jq --version || echo "install jq first"
# macOS:         brew install jq
# Ubuntu/Debian: sudo apt-get install -y jq
# Windows:       winget install jqlang.jq   (run hooks under Git Bash)
```

## Steps

**1. Copy the kit into the repo root**

```bash
cp -r kit/.claude   /path/to/your/repo/
cp -r kit/scripts   /path/to/your/repo/
mkdir -p /path/to/your/repo/docs && cp -r kit/docs/* /path/to/your/repo/docs/
```

**2. Make the hooks executable**

```bash
cd /path/to/your/repo
chmod +x .claude/hooks/*.sh
```

This step is easy to forget and the failure is silent — the hooks fail-safe,
so a non-executable hook produces an empty log rather than an error.

**3. Verify**

Start Claude Code in the repo, ask it to read any file, then:

```bash
ls ~/.claude/usage-logs/
cat ~/.claude/usage-logs/$(date -u +%Y-%m-%d).jsonl | head
```

You should see one JSON line per tool call. If the file is empty or missing,
see Troubleshooting.

Check the config loaded:

```
/hooks      # lists configured hooks and their source file
/agents     # should list scout and reviewer
/scout      # should be offered as a command
```

**4. Commit**

```bash
git add .claude scripts docs
git commit -m "Add Claude Code optimization kit"
```

Open it as a PR rather than pushing directly. Reviewers on the PR are how the
team finds out this exists, and the merge is the record that it was adopted.

## Troubleshooting

**Log file empty**
- `jq` missing → `jq --version`
- Hooks not executable → `chmod +x .claude/hooks/*.sh`
- Wrong directory → hooks resolve via `${CLAUDE_PROJECT_DIR}`; make sure you
  started Claude Code from the repo root
- Run `claude --debug-file /tmp/cc.log`, reproduce, then grep `/tmp/cc.log`
  for `hook`

**`/scout` or `/review` not offered**
- Files must be at `.claude/commands/*.md` and `.claude/agents/*.md`
- Restart the session; command and agent discovery happens at startup

**Secrets guard blocking something legitimate**
- Edit `BLOCKED_PATTERNS` in `.claude/hooks/guard-secrets.sh`
- Or delete the `PreToolUse` block from `.claude/settings.json`

**Windows**
- Hooks run under Git Bash. If Git Bash is absent, Claude Code falls back to
  PowerShell and these `.sh` scripts will not run. Install Git for Windows.
