#!/bin/bash
# total-recall: write-discipline guard (DISCIPLINE).
# Blocks creating a memory leaf note that lacks a valid `home:` frontmatter field
# (which index it belongs to). This is what keeps a growing collection navigable:
# every fact declares where it's filed. Pairs with memory-autoindex.sh (which then
# auto-files it). PreToolUse on Write. MEMORY.md / index files / archive are exempt.
# Set ENFORCE_HOME=0 in config to turn this off. Fails open.

set -uo pipefail
trap 'exit 0' ERR

command -v jq >/dev/null 2>&1 || exit 0
CONFIG="${TOTAL_RECALL_CONFIG:-$HOME/.config/total-recall/config}"
[ -f "$CONFIG" ] || exit 0
get_conf() { grep -E "^$1=" "$CONFIG" 2>/dev/null | tail -1 | cut -d= -f2- | sed 's/^"//;s/"$//' || true; }
MEM_DIR=$(get_conf MEM_DIR); [ -n "$MEM_DIR" ] || exit 0
[ "$(get_conf ENFORCE_HOME)" = "0" ] && exit 0

# Shared frontmatter helper — accepts a top-level `home:`/`description:` OR a harness-nested
# `metadata.<key>:`. Fall back to a top-level-only inline reader if the lib is absent.
LIB="${TOTAL_RECALL_LIB:-$(dirname "$0")/lib/memory-frontmatter.sh}"
# shellcheck source=/dev/null
[ -r "$LIB" ] && . "$LIB"
if ! command -v extract_fm_scalar >/dev/null 2>&1; then
  extract_fm_scalar() { awk -v key="$1" '
    /^---[[:space:]]*$/ { if(!fm){fm=1;next} exit } !fm{next}
    $0 ~ ("^" key ":[[:space:]]*") { sub("^[^:]+:[[:space:]]*",""); gsub(/"/,""); sub(/^[[:space:]]+/,""); sub(/[[:space:]]+$/,""); print; exit }'; }
fi

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
[ "$TOOL" = "Write" ] || exit 0
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
[ -z "$FILE_PATH" ] && exit 0
case "$FILE_PATH" in "$MEM_DIR"/*) ;; *) exit 0 ;; esac
case "$FILE_PATH" in *.md) ;; *) exit 0 ;; esac
[ -f "$FILE_PATH" ] && exit 0   # only guard NEW notes; never block overwriting an existing file
REL="${FILE_PATH#$MEM_DIR/}"
case "$REL" in
  MEMORY.md|MEMORY.md.bak-*) exit 0 ;;
  topics/*.md|projects/*.md) exit 0 ;;
  *INDEX.md) exit 0 ;;
  archive/*|.archive/*) exit 0 ;;
esac

CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // ""')
[ -z "$CONTENT" ] && exit 0
ALLOWED_FILE=$(get_conf ALLOWED_INDEXES); [ -z "$ALLOWED_FILE" ] && ALLOWED_FILE="$MEM_DIR/.allowed-indexes"
[ -r "$ALLOWED_FILE" ] || exit 0   # missing OR unreadable manifest -> fail open, don't deny

HOME_FIELD=$(printf '%s' "$CONTENT" | extract_fm_scalar home)
ALLOWED_LIST=$(tr '\n' ',' < "$ALLOWED_FILE" | sed 's/,$//;s/,/, /g')

emit_deny() { jq -nc --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'; }

if [ -z "$HOME_FIELD" ]; then
  emit_deny "Memory note '$REL' is missing a 'home:' field. Every note declares which index it belongs to so it stays findable. Add to frontmatter:

home: <index-file>

Known indexes: $ALLOWED_LIST
(If this needs a new index/domain, add it to $ALLOWED_FILE first.)"
  exit 0
fi
if ! grep -qFx "$HOME_FIELD" "$ALLOWED_FILE"; then
  emit_deny "Memory note '$REL' has home: '$HOME_FIELD', which isn't a known index.

Known indexes: $ALLOWED_LIST
To add a new one, append it to $ALLOWED_FILE."
  exit 0
fi

# Description is the search surface (what recall matches against + shows). Require a real one.
DESC=$(printf '%s' "$CONTENT" | extract_fm_scalar description)
DESC_WORDS=$(printf '%s' "$DESC" | wc -w | tr -d ' ')
if [ -z "$DESC" ] || [ "${DESC_WORDS:-0}" -lt 5 ]; then
  emit_deny "Memory note '$REL' needs a substantive 'description:'. It's the search surface — what recall matches against and shows you later — so a vague or empty one means the note won't be found. Write a one-line description (~5+ words) in the words you'd search for."
  exit 0
fi

# Soft, non-blocking nits (note IS allowed): missing created date, generic filename.
WARN=""
CREATED=$(printf '%s' "$CONTENT" | extract_fm_scalar created)
[ -z "$CREATED" ] && WARN="${WARN}no 'created:' date (used for staleness tracking); "
SLUG=$(basename "$REL" .md | sed -E 's/^(feedback|reference|project|user|tool)_//')
case "$SLUG" in
  note[0-9]*|temp*|misc*|untitled*|new|draft*|stuff|thing*|test|tmp*)
    WARN="${WARN}filename '$SLUG' is generic — name it by what you'd search for; " ;;
esac
[ -n "$WARN" ] && jq -nc --arg c "[memory nit — '$REL' was allowed] $WARN" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}'
exit 0
