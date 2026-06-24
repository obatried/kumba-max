#!/usr/bin/env bash
# kumba-max uninstaller. Conservative: removes the hooks/scripts/engine this kit
# installed and strips their settings.json entries. Leaves your memory notes,
# learn-loop state, and config alone. For a clean restore, use the ~/.claude.bak.*
# backup the installer made.

set -euo pipefail
say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

CLAUDE="$HOME/.claude"
HOOKS="$CLAUDE/hooks"
SETTINGS="$CLAUDE/settings.json"
CLAUDEMD="$CLAUDE/CLAUDE.md"

command -v jq >/dev/null 2>&1 || { echo "jq required to edit settings.json"; exit 1; }

KIT_HOOKS="stop-slash-text-guard gave-up-early-guard memory-home-required memory-autoindex \
total-recall-recall total-recall-dedup total-recall-rebuild learn-trigger learn-preflight \
learn-guard mem-surface commit-on-red-guard session-taint output-scanner persistence-guard \
gmail-approve calendar-approve email-html-guard capped-files-check"

say "Removing kit hooks..."
for h in $KIT_HOOKS; do rm -f "$HOOKS/$h.sh"; done
# shared helper sourced by the memory hooks; remove it and the lib dir if now empty
rm -f "$HOOKS/lib/memory-frontmatter.sh"; rmdir "$HOOKS/lib" 2>/dev/null || true
rm -f "$CLAUDE/scripts/output-scanner.py" "$CLAUDE/scripts/audit-claude-sync.sh"
rm -rf "$CLAUDE/memory-engine"

RE=$(echo "$KIT_HOOKS" | tr ' ' '\n' | grep -v '^$' | paste -sd'|' -)
if [ -f "$SETTINGS" ]; then
  say "Stripping kit hook entries from settings.json (backup first)..."
  cp "$SETTINGS" "$SETTINGS.bak-uninstall-$(date +%Y%m%d-%H%M%S)"
  TMP=$(mktemp)
  jq --arg re "$RE" '
    def strip($ev): .hooks[$ev] = ((.hooks[$ev] // []) | map(
      .hooks |= map(select((.command // "") | test($re) | not))
    ) | map(select((.hooks | length) > 0)));
    strip("SessionStart") | strip("UserPromptSubmit") | strip("PreToolUse") | strip("PostToolUse") | strip("Stop")
  ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
fi

if [ -f "$CLAUDEMD" ] && grep -qF "<!-- kumba-max:start -->" "$CLAUDEMD"; then
  say "Removing the appended kumba-max CLAUDE.md block..."
  BAK="$CLAUDEMD.bak-uninstall-$(date +%Y%m%d-%H%M%S)"
  cp "$CLAUDEMD" "$BAK"
  awk 'BEGIN{skip=0} /<!-- kumba-max:start -->/{skip=1} skip==0{print} /<!-- kumba-max:end -->/{skip=0}' \
    "$BAK" > "$CLAUDEMD" 2>/dev/null || true
fi

say "Done. Your memory (~/.claude/memory), learn state (~/.claude/state), and config were left untouched."
echo "For a full clean slate, restore the ~/.claude.bak.* backup the installer made."
