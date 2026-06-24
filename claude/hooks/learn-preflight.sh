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

# Keep only the bullet lines. Enforce by BULLET COUNT (8) and PER-LINE length (240),
# and WARN loudly when either is exceeded. A silent char-cut lets a bloated checklist
# degrade with no signal — the whole point is salience, so make a violation visible
# instead of quietly dropping the back half.
LINE_CAP=240
ALL=$(grep -E '^[[:space:]]*-[[:space:]]' "$PREFLIGHT" 2>/dev/null || true)
[ -z "$ALL" ] && exit 0
TOTAL=$(printf '%s\n' "$ALL" | grep -c .)
LONGEST=$(printf '%s\n' "$ALL" | head -n 8 | awk '{ if (length > m) m = length } END { print m + 0 }')
BODY=$(printf '%s\n' "$ALL" | head -n 8 | awk -v cap="$LINE_CAP" '{ if (length > cap) print substr($0, 1, cap) " …[TRUNCATED — bullet ran past the one-sentence cap]"; else print }')
[ -z "$BODY" ] && exit 0

# Loud, visible warnings (injected alongside the checklist) when the file violates its shape.
WARN=""
[ "$TOTAL" -gt 8 ] && WARN="${WARN}"$'\n'"⚠️ verify-preflight.md has $TOTAL bullets; only the first 8 are injected — it is over the bullet cap, compact it."
[ "$LONGEST" -gt "$LINE_CAP" ] && WARN="${WARN}"$'\n'"⚠️ a verify-preflight bullet ran past the ${LINE_CAP}-char one-sentence cap and was truncated in context — sharpen it."

# Build the entire payload with jq so escaping is always correct, regardless of
# quotes/backslashes/newlines/unicode in the checklist body.
jq -nc --arg body "$BODY" --arg warn "$WARN" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("[VERIFY-FIRST PREFLIGHT] Recurring checks to keep top-of-mind this session (maintained by /learn). Before asserting state as fact, run the check first:\n" + $body + $warn)
  }
}'
