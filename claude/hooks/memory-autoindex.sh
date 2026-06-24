#!/bin/bash
# total-recall: auto-filing (DISCIPLINE).
# After a memory note is written, append a one-line entry to the index named in its
# `home:` field, if not already there — so indexes stay in sync without manual upkeep.
# PostToolUse on Write/Edit/MultiEdit. Idempotent. MEMORY.md / index files / archive
# are skipped. Append is serialized via a portable mkdir mutex (stock macOS has no flock,
# and the old `flock -x 9 || exit 0` silently no-op'd the append on macOS). Every silent
# skip is logged so a regression can't go invisible for months. Fails open.

set -uo pipefail
trap 'exit 0' ERR

command -v jq >/dev/null 2>&1 || exit 0
CONFIG="${TOTAL_RECALL_CONFIG:-$HOME/.config/total-recall/config}"
[ -f "$CONFIG" ] || exit 0
get_conf() { grep -E "^$1=" "$CONFIG" 2>/dev/null | tail -1 | cut -d= -f2- | sed 's/^"//;s/"$//' || true; }
MEM_DIR=$(get_conf MEM_DIR); [ -n "$MEM_DIR" ] || exit 0

# Shared frontmatter helper — accepts a top-level `home:` OR a harness-nested
# `metadata.home:`. Fall back to a top-level-only inline reader if the lib is absent.
LIB="${TOTAL_RECALL_LIB:-$(dirname "$0")/lib/memory-frontmatter.sh}"
# shellcheck source=/dev/null
[ -r "$LIB" ] && . "$LIB"
if ! command -v extract_fm_scalar >/dev/null 2>&1; then
  extract_fm_scalar() { awk -v key="$1" '
    /^---[[:space:]]*$/ { if(!fm){fm=1;next} exit } !fm{next}
    $0 ~ ("^" key ":[[:space:]]*") { sub("^[^:]+:[[:space:]]*",""); gsub(/"/,""); sub(/^[[:space:]]+/,""); sub(/[[:space:]]+$/,""); print; exit }'; }
fi

DEBUG_LOG="$HOME/.cache/total-recall/autoindex.log"
log_skip() {  # log_skip <reason> <detail>
  mkdir -p "$(dirname "$DEBUG_LOG")" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$1" "${REL:-?}" "$2" >> "$DEBUG_LOG" 2>/dev/null || true
}

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
case "$TOOL" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
[ -z "$FILE_PATH" ] && exit 0
[ -f "$FILE_PATH" ] || exit 0
case "$FILE_PATH" in "$MEM_DIR"/*) ;; *) exit 0 ;; esac
REL="${FILE_PATH#$MEM_DIR/}"
case "$REL" in
  *..*) log_skip "bad-path" "$REL"; exit 0 ;;
  MEMORY.md|MEMORY.md.bak-*) exit 0 ;;
  topics/*.md|projects/*.md|projects/*/INDEX.md|*INDEX.md) exit 0 ;;
  archive/*|.archive/*) exit 0 ;;
esac

HOME_FIELD=$(extract_fm_scalar home < "$FILE_PATH")
[ -z "$HOME_FIELD" ] && { log_skip "no-home" ""; exit 0; }
# SECURITY: never append outside MEM_DIR. Reject traversal / absolute homes, and require
# the home to be a declared index (Edit/MultiEdit bypass the home-required guard, so a
# note with home: ../CLAUDE.md must not be able to make us write into the user's config).
case "$HOME_FIELD" in /*|*..*) log_skip "bad-home" "$HOME_FIELD"; exit 0 ;; esac
ALLOWED_FILE=$(get_conf ALLOWED_INDEXES); [ -z "$ALLOWED_FILE" ] && ALLOWED_FILE="$MEM_DIR/.allowed-indexes"
[ -f "$ALLOWED_FILE" ] && { grep -qFx "$HOME_FIELD" "$ALLOWED_FILE" || { log_skip "home-not-allowed" "$HOME_FIELD"; exit 0; }; }
INDEX_FILE="$MEM_DIR/$HOME_FIELD"
case "$INDEX_FILE" in "$MEM_DIR"/*) ;; *) exit 0 ;; esac
[ -f "$INDEX_FILE" ] || { log_skip "missing-index" "$HOME_FIELD"; exit 0; }

FILENAME=$(basename "$FILE_PATH")
INDEX_DIR=$(dirname "$INDEX_FILE")
# Pass paths as argv (NOT interpolated into the Python source) so a quote/odd char in a
# filename can't break parsing or inject code into the hook process.
REL_LINK=$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$FILE_PATH" "$INDEX_DIR" 2>/dev/null || echo "$FILENAME")

# Dedup by the exact link TARGET, not a bare basename (basename collisions across subdirs,
# or an incidental prose mention of the filename, would otherwise cause a false skip).
grep -qF "($REL_LINK)" "$INDEX_FILE" && exit 0

DESC=$(extract_fm_scalar description < "$FILE_PATH")
NAME=$(extract_fm_scalar name < "$FILE_PATH")
[ -z "$NAME" ] && NAME="${FILENAME%.md}"

# Portable mutex via mkdir — stock macOS ships no `flock`, and the old
# `flock -x 9 || exit 0` silently no-op'd the append on macOS. We only append while
# HOLDING the lock; if we can't get it we skip (logged) and let the next write retry —
# never an unlocked write. A lock older than 1 min is treated as orphaned (a prior run
# hard-killed before cleanup) and stolen. Our own lock releases via an EXIT trap.
LOCK_DIR="$INDEX_FILE.lockd"
got=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if mkdir "$LOCK_DIR" 2>/dev/null; then got=1; break; fi
  # Test find's OUTPUT, not its exit code — find exits 0 whether or not anything matched,
  # so `find … && rmdir` would always steal the lock.
  [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +1 2>/dev/null)" ] && rmdir "$LOCK_DIR" 2>/dev/null
  sleep 0.05
done
if [ "$got" != 1 ]; then log_skip "lock-timeout" "$REL_LINK"; exit 0; fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
if ! grep -qF "($REL_LINK)" "$INDEX_FILE"; then
  printf '\n- [%s](%s) — %s\n' "$NAME" "$REL_LINK" "$DESC" >> "$INDEX_FILE"
fi
exit 0
