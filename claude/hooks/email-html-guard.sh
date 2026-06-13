#!/bin/bash
# Email HTML guard (PreToolUse, OPINIONATED - optional).
#
# Blocks Gmail draft_email/send_email when:
#   - mimeType is not text/html (or multipart/alternative), OR
#   - htmlBody is empty, OR
#   - htmlBody contains any inline style= attribute
#
# Covers both gmail-mcp-server and workspace-mcp Gmail send/draft routes.
#
# Why: many users prefer Gmail's default rendering over inline styles
# (which often look broken in Gmail). This hook enforces that. SKIP this
# hook if you want to allow plain-text or inline-styled HTML.
#
# To enable: include in PreToolUse matcher in your settings.json.
# To skip:   omit from your matcher.

set -euo pipefail

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')

case "$TOOL" in
  mcp__gmail*__draft_email|mcp__gmail*__send_email)
    MIME=$(printf '%s' "$INPUT" | jq -r '.tool_input.mimeType // "text/plain"')
    HTML_BODY=$(printf '%s' "$INPUT" | jq -r '.tool_input.htmlBody // ""')
    ;;
  mcp__workspace-mcp__send_gmail_message|mcp__workspace-mcp__draft_gmail_message)
    FORMAT=$(printf '%s' "$INPUT" | jq -r '.tool_input.body_format // "plain"')
    HTML_BODY=$(printf '%s' "$INPUT" | jq -r '.tool_input.body // ""')
    if [ "$FORMAT" = "html" ]; then
      MIME="text/html"
    else
      MIME="text/plain"
    fi
    ;;
  *) exit 0 ;;
esac

if [ "$MIME" != "text/html" ] && [ "$MIME" != "multipart/alternative" ]; then
  {
    echo "BLOCKED: email mimeType is '$MIME' but must be 'text/html'."
    echo ""
    echo "Send emails as HTML. Use only bare tags:"
    echo "  <p>, <a>, <br>, <strong>, <em>, <ul><li>"
    echo "Zero inline styles. No font-family, font-size, color, or style= attributes."
  } >&2
  exit 2
fi

if [ -z "$HTML_BODY" ]; then
  {
    echo "BLOCKED: mimeType is '$MIME' but htmlBody is empty."
    echo "Set htmlBody to bare HTML (<p>, <a>, <strong> only, no styles)."
  } >&2
  exit 2
fi

if printf '%s' "$HTML_BODY" | grep -iqE 'style[[:space:]]*='; then
  {
    echo "BLOCKED: htmlBody contains an inline style= attribute."
    echo "Strip ALL style= attributes. Use only bare <p>, <a>, <strong>, <em>, <br>, <ul><li>."
  } >&2
  exit 2
fi

exit 0
