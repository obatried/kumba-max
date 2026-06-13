#!/bin/bash
# Gmail-approve hook (PreToolUse).
#
# Auto-approves Gmail actions that have zero blast radius:
#   - Any draft_email (drafts don't send, user must manually review/send)
#   - send_email when the ONLY recipient is one of your own accounts
#     (configured via CLAUDE_SHIELD_SELF_EMAILS env var) with no cc/bcc
#
# Everything else falls through to settings.json "ask" flow.
#
# Covers both gmail-mcp-server-style tools (mcp__gmail*__send_email,
# draft_email) and workspace-mcp tools (send_gmail_message,
# draft_gmail_message). The two differ in payload shape - gmail uses
# arrays for recipients, workspace-mcp uses single strings.
#
# Configuration:
#   export CLAUDE_SHIELD_SELF_EMAILS="you@example.com,you-alt@example.com"
#
# If CLAUDE_SHIELD_SELF_EMAILS is not set, self-send auto-approval is
# disabled - all sends fall through to ask.

set -euo pipefail

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')

allow() {
  local reason="$1"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":%s}}\n' \
    "$(printf '%s' "$reason" | jq -R -s '.')"
  exit 0
}

passthrough() { exit 0; }

# Parse self emails from env var (comma-separated). Lowercase for compare.
SELF_EMAILS_RAW="${CLAUDE_SHIELD_SELF_EMAILS:-}"

is_self_email() {
  local addr="$1"
  [ -z "$SELF_EMAILS_RAW" ] && return 1
  local lower
  lower=$(printf '%s' "$addr" | tr '[:upper:]' '[:lower:]')
  IFS=',' read -ra SELVES <<< "$SELF_EMAILS_RAW"
  for s in "${SELVES[@]}"; do
    s_lower=$(printf '%s' "$s" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    [ "$lower" = "$s_lower" ] && return 0
  done
  return 1
}

case "$TOOL" in
  mcp__gmail*__draft_email|mcp__workspace-mcp__draft_gmail_message)
    allow "Drafts require manual send, no blast radius"
    ;;

  mcp__gmail*__send_email)
    # gmail-mcp-server uses arrays for to/cc/bcc
    TO_ARR=$(printf '%s' "$INPUT" | jq -c '.tool_input.to // []')
    CC_ARR=$(printf '%s' "$INPUT" | jq -c '.tool_input.cc // []')
    BCC_ARR=$(printf '%s' "$INPUT" | jq -c '.tool_input.bcc // []')

    # Single-recipient self-send check
    TO_LEN=$(printf '%s' "$TO_ARR" | jq 'length')
    if [ "$TO_LEN" = "1" ] && [ "$CC_ARR" = "[]" ] && [ "$BCC_ARR" = "[]" ]; then
      TO_ADDR=$(printf '%s' "$TO_ARR" | jq -r '.[0]')
      if is_self_email "$TO_ADDR"; then
        allow "Send to self ($TO_ADDR), no cc/bcc"
      fi
    fi
    passthrough
    ;;

  mcp__workspace-mcp__send_gmail_message)
    # workspace-mcp uses single strings for to/cc/bcc
    TO=$(printf '%s' "$INPUT" | jq -r '.tool_input.to // ""')
    CC=$(printf '%s' "$INPUT" | jq -r '.tool_input.cc // ""')
    BCC=$(printf '%s' "$INPUT" | jq -r '.tool_input.bcc // ""')

    if [ -n "$TO" ] && [ -z "$CC" ] && [ -z "$BCC" ]; then
      if is_self_email "$TO"; then
        allow "Send to self ($TO) via workspace-mcp, no cc/bcc"
      fi
    fi
    passthrough
    ;;

  *)
    passthrough
    ;;
esac
