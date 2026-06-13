#!/bin/bash
# ~/.claude/hooks/learn-preflight.sh
# SessionStart hook (SOFT). Injects the rolling verify-first preflight checklist
# into context at the start of a session, so "verify before asserting" is ACTIVE
# from the first turn instead of buried in a memory file. This is the resurfacing
# half of the /learn flywheel: /learn writes verify-preflight.md, this surfaces it.
# Informational only — never blocks. No-op if the checklist file is missing.

set -uo pipefail
exec 2>/dev/null            # SOFT hook: never leak diagnostics to the host stream
trap 'exit 0' ERR

[ -n "${HOME:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

PREFLIGHT="$HOME/.claude/state/recursive-learning/verify-preflight.md"
[ -f "$PREFLIGHT" ] || exit 0

# Keep only the bullet lines. Cap by BULLET COUNT, not a mid-bullet char cut — a hard
# char cap silently drops the back half of the checklist once it grows past ~2 bullets,
# defeating the whole point of the preflight. Generous char backstop guards a runaway file.
BODY=$(grep -E '^[[:space:]]*-[[:space:]]' "$PREFLIGHT" 2>/dev/null | head -n 8 || true); BODY=${BODY:0:6000}
[ -z "$BODY" ] && exit 0

# Build the entire payload with jq so escaping is always correct, regardless of
# quotes/backslashes/newlines/unicode in the checklist body.
jq -nc --arg body "$BODY" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("[VERIFY-FIRST PREFLIGHT] Recurring checks to keep top-of-mind this session (maintained by /learn). Before asserting state as fact, run the check first:\n" + $body)
  }
}'
