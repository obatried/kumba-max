#!/bin/bash
# ~/.claude/hooks/learn-trigger.sh
# UserPromptSubmit hook (SOFT). Detects a conversational "wrapping up / closing
# the terminal" signal and injects a one-time reminder to consider running
# /learn. Informational only — NEVER blocks, never enforces. Throttled once per
# session. The agent decides whether the session was substantive enough to run.
#
# SHOULD match:  "wrapping up", "let's close this out", "done for today",
#                "I'm gonna close this terminal", "signing off", "that's all for now",
#                "let's continue this in a new terminal", "handoff", "resume tomorrow"
# Should NOT match: "done with this task", "close the modal", "sign off on this PR"
#                (task-level / non-session phrasing).

set -uo pipefail
exec 2>/dev/null            # SOFT hook: never leak diagnostics to the host stream
trap 'exit 0' ERR

# Guard HOME before any expansion (set -u would otherwise hard-fail if unset).
[ -n "${HOME:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0   # no jq → safe no-op (can't parse/emit)

STATE_DIR="$HOME/.claude/state"
LOG_FILE="$HOME/.claude/state/learn/learn-trigger.jsonl"
mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)

[ -z "$PROMPT" ] && exit 0

LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Session-end intent. Anchored to "end the session/terminal/chat" or explicit
# sign-off language, NOT bare "done/close" which fire constantly mid-task.
TRIGGERS='(wrap(ping)? (this|it|things)? ?up|wrap up here|close (this|the) (terminal|session|chat|window)( (out|down))?|clos(e|ing) (this|it) out|done for (today|the day|now)|that.?s (all|it) for (now|today)|signing off|sign off for|call(ing)? it (a day|here)|end (this|the) (session|terminal|chat)|that.?s a wrap|i.?m (done|good) (here|for (now|today))|let.?s (close|wrap) (this|it|things)( (out|up))?|document everything|continuation prompt|continue (on )?(another|a different) day|resume (this|it)? ?(later|tomorrow|another day|on another)|hand ?off|(continue|keep going|keep working|pick(ing)? (this|it) up).{0,30}(new|fresh|another) (terminal|tab|window)|(new|fresh|another) (terminal|tab|window).{0,30}(continue|keep going|keep working|and (go|keep)))'

grep -qE "$TRIGGERS" <<<"$LOWER" || exit 0

# Sanitize session id for safe use in a filename.
SAFE_SESSION_ID=$(printf '%s' "$SESSION_ID" | tr -cs 'A-Za-z0-9._-' '_')
[ -z "$SAFE_SESSION_ID" ] && SAFE_SESSION_ID="unknown"
THROTTLE_FILE="$STATE_DIR/learn-trigger-$SAFE_SESSION_ID"

# Self-hygiene: throttle files are only meaningful within their own session — prune
# stale ones so they don't accumulate forever on a long-lived install.
find "$STATE_DIR" -maxdepth 1 -name 'learn-trigger-*' -mtime +7 -delete 2>/dev/null || true

# Atomic once-per-session throttle: noclobber create wins exactly once.
( set -C; : > "$THROTTLE_FILE" ) 2>/dev/null || exit 0
date -u +%Y-%m-%dT%H:%M:%SZ > "$THROTTLE_FILE" 2>/dev/null || true

jq -nc \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg session "$SESSION_ID" \
   --arg matched_prompt "${PROMPT:0:200}" \
   '{ts:$ts, session:$session, matched_prompt:$matched_prompt}' \
   >> "$LOG_FILE" 2>/dev/null || true

jq -nc '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: "[LEARN REMINDER — soft] Wrap-up signal detected. If this session was substantive (you explained a procedure, the agent spent real effort finding a working path, a failure/recovery, or pushback from the user), consider running Skill({skill: \"learn\"}) before closing — it captures reusable playbooks so a problem solved once is never re-solved or re-explained, and installs a deny guard (or sharpens the verify-first preflight) for any real mistake. Skip it if the session was light. This is a nudge, not a gate — never block on it. Throttled once per session."
  }
}'
