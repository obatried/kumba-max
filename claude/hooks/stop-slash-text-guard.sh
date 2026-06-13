#!/bin/bash
# stop-slash-text-guard.sh
#
# A "Stop" hook — runs every time Claude Code finishes its turn.
#
# What it does: detects when Claude writes inert slash-text (like "/end" or
# "/ship") as the last line of a message instead of actually invoking the
# Skill tool. Logs each occurrence to a JSONL file so you can see the pattern.
#
# Design notes:
# - Audit only, never blocks. Blocking would force Claude to re-generate,
#   and re-gen often just deletes the line without fixing the underlying
#   mimicry, producing worse UX than the original bug.
# - Reads `last_assistant_message` from the stdin JSON Claude Code pipes in.
# - Respects `stop_hook_active` so it can't cause an infinite loop.
# - Fails open on any error: a broken hook should never wedge your session.
#
# To install: copy to ~/.claude/hooks/, make executable, wire it up in
# ~/.claude/settings.json under "hooks.Stop" (the kit's install.sh does this for you).

set -uo pipefail

LOG_DIR="$HOME/.claude/analytics"
LOG_FILE="$LOG_DIR/slash-text-violations.jsonl"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# Read stdin. Fail open if unreadable.
INPUT=$(cat 2>/dev/null) || exit 0
[ -z "$INPUT" ] && exit 0

# Require jq; fail open if unavailable.
command -v jq >/dev/null 2>&1 || exit 0

# Loop-break: if we already ran on this stop, don't re-engage.
STOP_ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
[ "$STOP_ACTIVE" = "true" ] && exit 0

LAST_MSG=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null)
[ -z "$LAST_MSG" ] && exit 0

# Extract last non-empty line.
LAST_LINE=$(printf '%s' "$LAST_MSG" | awk 'NF {last=$0} END {print last}')
[ -z "$LAST_LINE" ] && exit 0

# Detect patterns like "/end", "/End.", "- /end", "**/end**", etc.
# Strip leading/trailing ** first to catch bolded variants.
CANDIDATE=$(printf '%s' "$LAST_LINE" | sed -E 's/^\*\*//; s/\*\*$//')
if printf '%s' "$CANDIDATE" | grep -qiE '^[[:space:]]*[-*>]?[[:space:]]*/[A-Za-z][[:alnum:]_-]*[.!]?[[:space:]]*$'; then
  SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq -cn \
    --arg ts "$TIMESTAMP" \
    --arg sid "$SESSION_ID" \
    --arg line "$LAST_LINE" \
    '{timestamp: $ts, session_id: $sid, matched_line: $line}' \
    >> "$LOG_FILE" 2>/dev/null || true
fi

exit 0
