#!/bin/bash
# commit-on-red-guard.sh
# PreToolUse(Bash) guard, facet: "commit on red".
# Catches a `git commit` that runs REGARDLESS of a test/check in the SAME command
# (the unconditional-sequencing trap), while leaving the SAFE short-circuit pattern
# `test && git commit` untouched.
#
# Decision (single-command layer — the only thing a PreToolUse hook can see; the
# "commit in a separate later step without reading the result" case is invisible
# here):
#   - No `git commit` in the command            -> silent allow (not our concern).
#   - `git commit` but no test token BEFORE it   -> allow, log as commit_no_prior_test.
#   - test token precedes commit: inspect the CONNECTOR (text between the last test
#     token and `git commit`):
#       contains && and none of ; \n || &       -> SAFE (gated)        -> allow.
#       otherwise (;, newline, ||, or bare &)    -> UNSAFE (ungated)    -> would-block.
#
# MODE: ~/.claude/state/recursive-learning/COMMIT_RED_MODE  (default "log").
#   log     -> classify + append jsonl, ALWAYS allow (shadow).
#   enforce -> on UNSAFE, deny once with a fix hint.
# Fail-open ALWAYS: any internal error exits 0 (allow). Known FP: a `;`/`git commit`
# living inside a quoted string (e.g. echo "a; git commit") — accepted in shadow,
# reviewed from the log before enforce. START IN log; flip to enforce only once the
# log shows the false-alarm rate is low for your workflow.

set -uo pipefail
exec 2>/dev/null
trap 'exit 0' ERR

[ -n "${HOME:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

MODE_FILE="$HOME/.claude/state/recursive-learning/COMMIT_RED_MODE"
LOG="$HOME/.claude/state/learn/commit-on-red-guard.jsonl"
mkdir -p "$(dirname "$LOG")" "$(dirname "$MODE_FILE")" 2>/dev/null || true
MODE="log"; [ -f "$MODE_FILE" ] && MODE=$(tr -d ' \n\r' < "$MODE_FILE" 2>/dev/null); [ -z "$MODE" ] && MODE="log"

INPUT=$(cat) || exit 0
[ -z "$INPUT" ] && exit 0
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
[ "$TOOL" = "Bash" ] || exit 0
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
[ -z "$CMD" ] && exit 0

# Only events that contain a real `git commit` are interesting; everything else is silent.
printf '%s' "$CMD" | grep -qE 'git[[:space:]]+commit' || exit 0

# Known check/test runners. NOTE: no trailing word-boundary group here — the connector
# extraction strips greedily up to a matched token, and a trailing boundary char would
# eat the first operator char (turning `tsc&&commit` into a false unsafe). Tokens are
# distinctive enough that bare-substring matches are an acceptable shadow-mode risk.
TEST_RE='(npm|pnpm|yarn|bun)[[:space:]]+(run[[:space:]]+)?(test|lint|typecheck|tsc|check)|jest|vitest|mocha|pytest|tox|nox|tsc|eslint|biome|mypy|pyright|ruff|rspec|phpunit|ctest|bats|(go|cargo|deno)[[:space:]]+(test|check)|make[[:space:]]+(test|check|lint)|pre-commit[[:space:]]+run'

# Normalize newlines to ';' so multi-line scripts are treated as unconditional sequencing.
NORM=$(printf '%s' "$CMD" | tr '\n' ';')
BEFORE=${NORM%%git commit*}     # text before the first `git commit`

DECISION="commit_no_prior_test"
CONNECTOR=""
if printf '%s' "$BEFORE" | grep -qiE "$TEST_RE"; then
  # Connector = what remains after stripping greedily up to the LAST test token.
  CONNECTOR=$(printf '%s' "$BEFORE" | sed -E "s/.*($TEST_RE)//")
  if printf '%s' "$CONNECTOR" | grep -qE '&&' \
     && ! printf '%s' "$CONNECTOR" | grep -qE ';|\|\||(^|[^&])&([^&]|$)'; then
    DECISION="safe_gated"
  else
    DECISION="unsafe_unconditional"
  fi
fi

# Shadow log (one line; truncate command for sanity).
CMD_TRUNC=$(printf '%s' "$CMD" | cut -c1-300)
jq -nc \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg mode "$MODE" \
  --arg decision "$DECISION" \
  --arg connector "$(printf '%s' "$CONNECTOR" | cut -c1-60)" \
  --arg cmd "$CMD_TRUNC" \
  '{ts:$ts, mode:$mode, decision:$decision, connector:$connector, cmd:$cmd}' \
  >> "$LOG" 2>/dev/null || true

# Log mode (default): never block.
[ "$MODE" != "enforce" ] && exit 0
[ "$DECISION" != "unsafe_unconditional" ] && exit 0

jq -nc '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"commit-on-red guard: this command runs `git commit` regardless of the test/check before it (joined by ; newline || or &, not &&), so the commit fires even when the check fails. Use `<check> && git commit` so the commit only runs on green — or run the check in its own step, read the green result, then commit separately."}}'
exit 0
