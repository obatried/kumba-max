#!/bin/bash
# Persistence-write guard.
#
# Fires on Edit, Write, MultiEdit. If the target path is a "persistence"
# file (one that affects future sessions: claude config/hooks/scripts,
# launchd plists, shell rcs, SSH/AWS/k8s/Docker creds, etc), check the
# session-taint marker written by session-taint.sh.
#
# Logic:
#   - Path is NOT persistence       -> pass through (no decision)
#   - Path IS persistence, no taint -> allow silently (clean session;
#                                      you're just editing config yourself)
#   - Path IS persistence, tainted  -> pass through with warning (settings.json
#                                      ask flow surfaces the prompt with reason)
#
# Threat model: an injected prompt in an email/web page/notion doc
# convinces the agent to drop a backdoor in ~/.claude/settings.json or
# ~/.zshrc. The taint marker indicates the agent has seen external
# content this session - that's the only state in which a persistence
# write should require attention.

set -euo pipefail

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')

case "$TOOL" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

EXPANDED="${FILE_PATH/#\~/$HOME}"

is_persistence=0
case "$EXPANDED" in
  "$HOME/.claude/settings"*.json|\
  "$HOME/.claude/hooks/"*|\
  "$HOME/.claude/scripts/"*|\
  "$HOME/.claude/agents/"*|\
  "$HOME/.claude/skills/"*|\
  "$HOME/.claude/commands/"*|\
  "$HOME/.claude/CLAUDE.md"|\
  "$HOME/.claude/CLAUDE_"*.md|\
  "$HOME/.claude.json"|\
  "$HOME/.zshrc"|\
  "$HOME/.bashrc"|\
  "$HOME/.zprofile"|\
  "$HOME/.bash_profile"|\
  "$HOME/.profile"|\
  "$HOME/.ssh/"*|\
  "$HOME/.aws/"*|\
  "$HOME/.gnupg/"*|\
  "$HOME/.docker/config.json"|\
  "$HOME/.kube/config"|\
  "$HOME/Library/LaunchAgents/"*|\
  "$HOME/Library/LaunchDaemons/"*)
    is_persistence=1
    ;;
esac

if [ "$is_persistence" -eq 0 ]; then
  exit 0
fi

if [ -z "$SESSION_ID" ]; then
  SESSION_ID="ppid-$PPID"
fi
TAINT_FILE="/tmp/cc-taint-$SESSION_ID"

if [ -s "$TAINT_FILE" ]; then
  SOURCES=$(head -3 "$TAINT_FILE" | tr '\n' ',' | sed 's/,$//')
  {
    echo "ATTENTION: writing to persistence path '$EXPANDED'."
    echo "This session has read from untrusted sources: $SOURCES"
    echo "Verify this write is intended before approving."
  } >&2
  exit 0
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Persistence write in clean session (no taint sources)"}}\n'
exit 0
