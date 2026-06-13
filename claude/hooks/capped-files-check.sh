#!/bin/bash
# ~/.claude/hooks/capped-files-check.sh
# SessionStart hook (SOFT). Warns when a registered "lean" doc has bloated past its
# byte budget — the durable fix for silent doc-bloat (line-count caps get gamed, so this
# enforces by size, automatically, every session). Never blocks; no-op when all clean.
#
# Registry: ~/.claude/state/capped-files.tsv  — one entry per line:  <glob> <byte-budget> [max-line-bytes]
#   - lines starting with # are ignored; globs must not contain spaces.
#   - add a new project/file = add one line.  (For ASCII / markdown, bytes ≈ chars.)
#   - optional 3rd col [max-line-bytes]: ALSO flag if any single line exceeds it — catches
#     one-giant-line bloat that slips under the total budget (the 24KB-on-one-line failure).
#     Checked with awk ONLY on files already under the total budget, so an over-budget
#     (possibly huge) file is flagged by stat and never read → no stall risk.
# Override the registry path with CAPPED_FILES_REG (used for testing).

set -uo pipefail
exec 2>/dev/null            # SOFT hook: never leak diagnostics to the host stream
trap 'exit 0' ERR

[ -n "${HOME:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

REG="${CAPPED_FILES_REG:-$HOME/.claude/state/capped-files.tsv}"
[ -f "$REG" ] || exit 0

MAX_OFFENDERS=30
violations=""
count=0

# `|| [ -n ... ]` so a final line without a trailing newline is still processed.
while read -r glob budget maxline _rest || [ -n "${glob:-}" ]; do
  [ -z "${glob:-}" ] && continue
  glob="${glob%$'\r'}"
  case "$glob" in \#*) continue ;; esac
  budget="${budget:-}"; budget="${budget%$'\r'}"
  case "$budget" in ''|*[!0-9]*) continue ;; esac      # strict: skip malformed budgets
  maxline="${maxline:-}"; maxline="${maxline%$'\r'}"    # optional 3rd col; validated at use
  glob="${glob/#\~/$HOME}"
  for f in $glob; do
    [ -f "$f" ] || continue
    # stat = metadata only (no file read), so a stray match on a huge file can't stall.
    size=$(stat -f %z "$f" 2>/dev/null || stat -c %s "$f" 2>/dev/null || wc -c < "$f" 2>/dev/null)
    size="${size//[^0-9]/}"
    [ -z "$size" ] && continue
    if [ "$size" -gt "$budget" ]; then
      violations="${violations}- ${f/#$HOME/~}: ${size} bytes > ${budget} budget (over by $((size - budget))) — trim it.
"
      count=$((count + 1))
      [ "$count" -ge "$MAX_OFFENDERS" ] && break 2
    else
      # Under total budget → cheap & safe to read. Optional per-line cap catches one giant
      # line hiding under the total (e.g. an unscannable 3KB run-on in an otherwise small file).
      case "$maxline" in
        ''|*[!0-9]*) : ;;                               # no / invalid 3rd col → skip line check
        *)
          longest=$(awk '{ if (length > m) m = length } END { print m + 0 }' "$f" 2>/dev/null)
          longest="${longest//[^0-9]/}"
          if [ -n "$longest" ] && [ "$longest" -gt "$maxline" ]; then
            violations="${violations}- ${f/#$HOME/~}: longest line ${longest} chars > ${maxline} cap — one line is hogging the file; break it up.
"
            count=$((count + 1))
            [ "$count" -ge "$MAX_OFFENDERS" ] && break 2
          fi
        ;;
      esac
    fi
  done
done < "$REG"

[ -z "$violations" ] && exit 0

printf '%s' "$violations" | jq -Rsc '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: ("[CAPPED-FILES] These lean docs are over budget (line-count caps get gamed — this checks bytes + max single-line). Trim before adding more:\n" + .)
  }
}'
exit 0
