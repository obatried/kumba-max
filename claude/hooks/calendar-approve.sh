#!/bin/bash
# Calendar-approve hook (PreToolUse).
#
# Auto-approves calendar tool calls on your own calendar when no external
# attendees are being added. Mirrors gmail-approve.sh.
#
# Covers all variants:
#   workspace-mcp: manage_event, create_event, update_event, delete_event,
#                  respond_to_event, manage_focus_time, manage_out_of_office
#   gcal:          create-event, create-events, update-event, delete-event,
#                  respond-to-event
#
# Configuration (same env var as gmail-approve):
#   export CLAUDE_SHIELD_SELF_EMAILS="you@example.com,you-alt@example.com"
#
# Everything else falls through to settings.json "ask" flow.

set -euo pipefail

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')

SELF_EMAILS_RAW="${CLAUDE_SHIELD_SELF_EMAILS:-}"
# Build JSON array of selves for jq
if [ -n "$SELF_EMAILS_RAW" ]; then
  SELVES=$(printf '%s' "$SELF_EMAILS_RAW" | tr ',' '\n' | jq -R -s 'split("\n") | map(select(length > 0) | ascii_downcase)')
else
  SELVES='[]'
fi

allow() {
  local reason="$1"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$reason" | jq -R -s '.')"
  exit 0
}

passthrough() { exit 0; }

# Returns 0 (safe) if attendees is empty/null or contains only self emails.
# Handles both ["email@x"] and [{"email":"email@x"}] shapes.
attendees_safe() {
  local payload="$1"
  printf '%s' "$payload" | jq -e --argjson selves "$SELVES" '
    (. // []) as $a
    | $a
    | map(if type == "string" then . elif type == "object" then (.email // "") else "" end)
    | map(ascii_downcase)
    | map(select(. != "" and (IN($selves[]) | not)))
    | length == 0
  ' >/dev/null
}

case "$TOOL" in
  mcp__workspace-mcp__manage_event)
    ACTION=$(printf '%s' "$INPUT" | jq -r '.tool_input.action // ""')
    case "$ACTION" in
      delete|rsvp)
        # Delete/RSVP fire notifications to existing attendees. Auto-allow only
        # when no attendees are present in the payload; otherwise passthrough.
        ATTENDEES=$(printf '%s' "$INPUT" | jq -c '.tool_input.attendees // null')
        if attendees_safe "$ATTENDEES"; then
          allow "$ACTION - no external attendees in payload"
        else
          passthrough
        fi
        ;;
      create|update)
        ATTENDEES=$(printf '%s' "$INPUT" | jq -c '.tool_input.attendees // null')
        if attendees_safe "$ATTENDEES"; then
          allow "$ACTION with no external attendees"
        else
          passthrough
        fi
        ;;
      *)
        passthrough
        ;;
    esac
    ;;

  mcp__workspace-mcp__create_event|mcp__workspace-mcp__update_event|mcp__gcal__create-event|mcp__gcal__update-event)
    ATTENDEES=$(printf '%s' "$INPUT" | jq -c '.tool_input.attendees // null')
    if attendees_safe "$ATTENDEES"; then
      allow "Calendar event with no external attendees"
    else
      passthrough
    fi
    ;;

  mcp__workspace-mcp__delete_event|mcp__gcal__delete-event)
    # Delete fires a cancellation notification to existing attendees. Auto-allow
    # only when no attendees are present in the payload; otherwise passthrough.
    ATTENDEES=$(printf '%s' "$INPUT" | jq -c '.tool_input.attendees // null')
    if attendees_safe "$ATTENDEES"; then
      allow "Calendar deletion - no external attendees in payload"
    else
      passthrough
    fi
    ;;

  mcp__workspace-mcp__respond_to_event|mcp__gcal__respond-to-event)
    # RSVP fires a response notification to the organizer. Auto-allow only
    # when no attendees are present in the payload (event has no humans);
    # otherwise passthrough so the user sees who they're notifying.
    ATTENDEES=$(printf '%s' "$INPUT" | jq -c '.tool_input.attendees // null')
    if attendees_safe "$ATTENDEES"; then
      allow "RSVP - no external attendees in payload"
    else
      passthrough
    fi
    ;;

  mcp__workspace-mcp__manage_focus_time|mcp__workspace-mcp__manage_out_of_office)
    allow "Focus time / OOO - solo by definition"
    ;;

  mcp__gcal__create-events)
    # Batch: all events in the batch must be attendee-safe
    if printf '%s' "$INPUT" | jq -e --argjson selves "$SELVES" '
      [.tool_input.events[]?.attendees? // [] | .[]]
      | map(if type == "string" then . elif type == "object" then (.email // "") else "" end)
      | map(ascii_downcase)
      | map(select(. != "" and (IN($selves[]) | not)))
      | length == 0
    ' >/dev/null; then
      allow "Batch event create with no external attendees"
    else
      passthrough
    fi
    ;;

  *)
    passthrough
    ;;
esac
