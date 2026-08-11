---
description: Review the current diff with the read-only reviewer agent
argument-hint: [optional: --staged, or a path to narrow scope]
---

Use the `reviewer` subagent to review the current change set.

Scope: $ARGUMENTS

Pass the reviewer's findings through verbatim. Do not soften blocking items,
and do not start fixing anything until I say so.
