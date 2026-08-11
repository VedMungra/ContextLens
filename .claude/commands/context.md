---
description: Audit what is currently loaded in context and suggest what to drop
---

Audit the current session's context usage. Report:

1. **Loaded** — which files you have read this session, and roughly how much
   of the context window they account for.
2. **Stale** — which of those are no longer relevant to what we are doing now.
3. **Oversized** — any file you read in full where a targeted range or a grep
   would have been enough.
4. **Recommendation** — whether to continue, or `/clear` and restart with only
   the files that still matter. Say which files those are.

Be blunt. If the session is still lean, say so in one line and stop.
