#!/bin/bash
# Output scanner - PostToolUse.
#
# Scans red-tool responses (Gmail/web/Notion/Slack/Drive/browser reads) against
# a prompt-injection pattern library at ~/.claude/data/injection-patterns.json.
#
# Alarm-only: writes warnings to stderr (Claude sees these in system context)
# and logs to /tmp/cc-injection-log-$SESSION_ID. Never blocks.
#
# Two threat classes covered:
#   1. Exfil    - content trying to make Claude send data somewhere
#   2. Steering - content trying to redirect Claude away from your task

set -euo pipefail

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""')
[ -z "$SESSION_ID" ] && SESSION_ID="ppid-$PPID"

case "$TOOL" in
  mcp__gmail*__read_email|mcp__gmail*__search_emails|mcp__gmail*__download_attachment) ;;
  mcp__workspace-mcp__search_gmail_messages|mcp__workspace-mcp__get_gmail_message_content|mcp__workspace-mcp__get_gmail_messages_content_batch|mcp__workspace-mcp__get_gmail_thread_content|mcp__workspace-mcp__get_gmail_threads_content_batch|mcp__workspace-mcp__get_gmail_attachment_content) ;;
  mcp__workspace-mcp__search_drive_files|mcp__workspace-mcp__list_drive_items|mcp__workspace-mcp__get_drive_file_content|mcp__workspace-mcp__search_docs|mcp__workspace-mcp__get_doc_content|mcp__workspace-mcp__get_doc_as_markdown|mcp__workspace-mcp__inspect_doc_structure|mcp__workspace-mcp__export_doc_to_pdf|mcp__workspace-mcp__read_sheet_values|mcp__workspace-mcp__list_document_comments|mcp__workspace-mcp__list_spreadsheet_comments) ;;
  mcp__notion__API-retrieve-*|mcp__notion__API-query-*|mcp__notion__API-get-*|mcp__notion__API-post-search|mcp__notion__API-list-data-source-templates) ;;
  mcp__slack__conversations_history|mcp__slack__conversations_replies|mcp__slack__conversations_search_messages|mcp__slack__conversations_unreads|mcp__slack__users_search) ;;
  WebFetch|WebSearch) ;;
  mcp__tavily__*|mcp__exa__*|mcp__firecrawl__*|mcp__jina__*|mcp__linkup__*|mcp__youdotcom__*|mcp__beehiiv__*) ;;
  mcp__chrome-devtools*__take_snapshot|mcp__chrome-devtools*__take_screenshot|mcp__chrome-devtools*__list_console_messages|mcp__chrome-devtools*__get_console_message|mcp__chrome-devtools*__list_network_requests|mcp__chrome-devtools*__get_network_request|mcp__chrome-devtools*__evaluate_script) ;;
  mcp__playwright__browser_snapshot|mcp__playwright__browser_take_screenshot|mcp__playwright__browser_console_messages|mcp__playwright__browser_evaluate|mcp__playwright__browser_network_requests|mcp__playwright__browser_network_request) ;;
  *) exit 0 ;;
esac

PATTERNS_FILE="${CLAUDE_SHIELD_PATTERNS:-$HOME/.claude/data/injection-patterns.json}"
LOG_FILE="/tmp/cc-injection-log-$SESSION_ID"

if [ ! -f "$PATTERNS_FILE" ]; then
  exit 0
fi

SCANNER_SCRIPT="${CLAUDE_SHIELD_SCANNER:-$HOME/.claude/scripts/output-scanner.py}"
if [ ! -f "$SCANNER_SCRIPT" ]; then
  exit 0
fi

printf '%s' "$INPUT" | python3 "$SCANNER_SCRIPT" "$PATTERNS_FILE" "$TOOL" "$LOG_FILE"
exit 0
