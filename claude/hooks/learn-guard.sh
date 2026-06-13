#!/bin/bash
# ~/.claude/hooks/learn-guard.sh
# PreToolUse ENFORCEMENT hook for the /learn recursive-learning loop.
# Reads machine-readable guard specs and DENIES a tool call that matches a guard
# /learn installed for a previously-corrected, DETECTABLE mistake. This is the
# layer that turns "we discussed it" into "it cannot happen again" for the
# detectable subset.
#
# Specs file (JSON array): ~/.claude/state/guards/guard-specs.json
#   {"type":"deny_write_path","path":"/abs/path","reason":"why"}   -> deny Write/Edit/MultiEdit to that exact path
#   {"type":"deny_bash_regex","pattern":"ERE","reason":"why"}      -> deny a Bash command matching the regex
#
# SAFETY MODEL:
# - Empty/absent specs file => total no-op (never denies anything). Safe to install.
# - Matching is deterministic exact-path / explicit-regex; it never guesses.
# - On any INTERNAL error (no jq, bad input, bad specs) the hook exits 0 = ALLOW,
#   so a hook bug can never brick the session (fail-open on crash). It only ever
#   denies on a clean, explicit match. Coverage gap: Bash writes to a protected
#   path via redirect/cp/mv are only caught if a deny_bash_regex is added for them;
#   the file-tool guard (Write/Edit/MultiEdit) is exact and complete.

set -uo pipefail
exec 2>/dev/null
trap 'exit 0' ERR

[ -n "${HOME:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

SPECS="$HOME/.claude/state/guards/guard-specs.json"
[ -f "$SPECS" ] || exit 0
# specs must be a non-empty JSON array, else no-op
jq -e 'type=="array" and length>0' "$SPECS" >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
[ -z "$TOOL" ] && exit 0

deny() {
  jq -nc --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

case "$TOOL" in
  Write|Edit|MultiEdit)
    TARGET=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""')
    [ -z "$TARGET" ] && exit 0
    # Decide on the PATH MATCH, not on the reason — a matching spec with an empty
    # reason must still deny (fall back to a default reason).
    COUNT=$(jq --arg t "$TARGET" '[.[] | select(.type=="deny_write_path" and .path==$t)] | length' "$SPECS")
    if [ "${COUNT:-0}" -gt 0 ] 2>/dev/null; then
      REASON=$(jq -r --arg t "$TARGET" '[.[] | select(.type=="deny_write_path" and .path==$t)][0].reason // ""' "$SPECS")
      [ -z "$REASON" ] && REASON="This path is guarded by /learn after a prior mistake. Write to a different path."
      deny "$REASON"
    fi
    ;;
  Bash)
    CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
    [ -z "$CMD" ] && exit 0
    # Iterate by index and pull each pattern RAW (jq -r). Do NOT use @tsv here —
    # @tsv escapes backslashes, which silently corrupts any regex containing \b, \d, etc.
    N=$(jq 'length' "$SPECS")
    i=0
    while [ "$i" -lt "${N:-0}" ]; do
      if [ "$(jq -r ".[$i].type // \"\"" "$SPECS")" = "deny_bash_regex" ]; then
        pat=$(jq -r ".[$i].pattern // \"\"" "$SPECS")
        if [ -n "$pat" ] && grep -qE "$pat" <<<"$CMD"; then
          reason=$(jq -r ".[$i].reason // \"\"" "$SPECS")
          [ -z "$reason" ] && reason="This command is blocked by /learn after a prior mistake."
          deny "$reason"
        fi
      fi
      i=$((i+1))
    done
    ;;
esac
exit 0
