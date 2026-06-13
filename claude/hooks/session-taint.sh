#!/bin/bash
# Session-taint tracker.
#
# Runs on every PostToolUse. If the tool that just ran was a "red" tool
# (one that reads attacker-controllable content — gmail/web/notion/slack/
# drive/docs/browser-snapshot), append a marker to /tmp/cc-taint-$SESSION_ID.
#
# The marker is read by persistence-guard.sh and any other PreToolUse
# hook that wants to know "has this session been exposed to untrusted
# content yet."
#
# Always exits 0 — this hook never blocks or alters tool execution.

set -euo pipefail

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""')

if [ -z "$SESSION_ID" ]; then
  SESSION_ID="ppid-$PPID"
fi

TAINT_FILE="/tmp/cc-taint-$SESSION_ID"

taint() {
  local source="$1"
  if [ ! -f "$TAINT_FILE" ] || ! grep -qxF "$source" "$TAINT_FILE" 2>/dev/null; then
    printf '%s\n' "$source" >> "$TAINT_FILE"
  fi
}

case "$TOOL" in
  # Gmail reads (any of the 4 accounts)
  mcp__gmail*__read_email|mcp__gmail*__search_emails|mcp__gmail*__download_attachment)
    taint "gmail-read:$TOOL"
    ;;

  # Workspace-mcp gmail reads
  mcp__workspace-mcp__search_gmail_messages|mcp__workspace-mcp__get_gmail_message_content|mcp__workspace-mcp__get_gmail_messages_content_batch|mcp__workspace-mcp__get_gmail_thread_content|mcp__workspace-mcp__get_gmail_threads_content_batch|mcp__workspace-mcp__get_gmail_attachment_content)
    taint "workspace-gmail-read:$TOOL"
    ;;

  # Workspace-mcp drive/docs/sheets reads
  mcp__workspace-mcp__search_drive_files|mcp__workspace-mcp__list_drive_items|mcp__workspace-mcp__get_drive_file_content|mcp__workspace-mcp__search_docs|mcp__workspace-mcp__get_doc_content|mcp__workspace-mcp__get_doc_as_markdown|mcp__workspace-mcp__inspect_doc_structure|mcp__workspace-mcp__export_doc_to_pdf|mcp__workspace-mcp__read_sheet_values|mcp__workspace-mcp__list_document_comments|mcp__workspace-mcp__list_spreadsheet_comments)
    taint "workspace-doc-read:$TOOL"
    ;;

  # Notion reads
  mcp__notion__API-retrieve-*|mcp__notion__API-query-*|mcp__notion__API-get-*|mcp__notion__API-post-search|mcp__notion__API-list-data-source-templates)
    taint "notion-read:$TOOL"
    ;;

  # Slack reads
  mcp__slack__conversations_history|mcp__slack__conversations_replies|mcp__slack__conversations_search_messages|mcp__slack__conversations_unreads|mcp__slack__users_search)
    taint "slack-read:$TOOL"
    ;;

  # Web fetches (built-in + MCP)
  WebFetch|WebSearch)
    taint "web:$TOOL"
    ;;
  mcp__tavily__*|mcp__exa__*|mcp__firecrawl__*|mcp__jina__*|mcp__linkup__*|mcp__youdotcom__*|mcp__beehiiv__*)
    taint "web:$TOOL"
    ;;

  # Browser surfaces (chrome-devtools, playwright)
  mcp__chrome-devtools*__take_snapshot|mcp__chrome-devtools*__take_screenshot|mcp__chrome-devtools*__list_console_messages|mcp__chrome-devtools*__get_console_message|mcp__chrome-devtools*__list_network_requests|mcp__chrome-devtools*__get_network_request|mcp__chrome-devtools*__evaluate_script)
    taint "browser:$TOOL"
    ;;
  mcp__playwright__browser_snapshot|mcp__playwright__browser_take_screenshot|mcp__playwright__browser_console_messages|mcp__playwright__browser_evaluate|mcp__playwright__browser_network_requests|mcp__playwright__browser_network_request)
    taint "browser:$TOOL"
    ;;
esac

exit 0
