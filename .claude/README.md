# .claude/ — shared Claude Code configuration

Committed to the repo so every engineer gets identical behaviour.

- `settings.json` — wires the hooks. Hook entries **merge** across settings
  levels, so this does not overwrite anyone's personal
  `~/.claude/settings.json` hooks.
- `hooks/` — must be executable (`chmod +x .claude/hooks/*.sh`). All fail
  silently by design: a broken measurement tool must never block work.
- `agents/` — `scout` (Haiku, search) and `reviewer` (Sonnet, read-only).
- `commands/` — `/scout`, `/review`, `/context`.

To remove the secrets guard, delete the `PreToolUse` block from
`settings.json`. To stop logging, delete the `PostToolUse` block.

See `docs/INSTALL.md` for setup and `docs/PRIVACY.md` for what is recorded.
