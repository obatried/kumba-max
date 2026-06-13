#!/usr/bin/env bash
# audit-claude-sync.sh
# Two checks against your CLAUDE.md, intended to run weekly via cron or launchd:
#   (1) Drift: companion hook/skill/script listed in CLAUDE_MAP.md
#       whose mtime is >30 days from CLAUDE.md's mtime.
#   (2) Freshness: sections whose `Last reviewed:` date is >90 days old.
# Either finding writes a reminder file you can wire into your daily/weekly digest.
#
# Note: this script uses BSD `stat -f` and `date -j -f` (macOS). For Linux,
# swap to GNU `stat -c %Y` and `date -d`. Tested on macOS.

set -euo pipefail

CLAUDE_MD="${CLAUDE_MD:-$HOME/.claude/CLAUDE.md}"
MAP_FILE="${MAP_FILE:-$HOME/.claude/CLAUDE_MAP.md}"
REMINDER_DIR="${REMINDER_DIR:-$HOME/.claude/state/reminders}"
REMINDER_FILE="$REMINDER_DIR/claude-sync-drift.md"

DRIFT_THRESHOLD_DAYS=30
DRIFT_THRESHOLD_SEC=$((DRIFT_THRESHOLD_DAYS * 86400))
FRESHNESS_THRESHOLD_DAYS=90
FRESHNESS_THRESHOLD_SEC=$((FRESHNESS_THRESHOLD_DAYS * 86400))
NOW_EPOCH=$(date +%s)

[[ ! -f "$CLAUDE_MD" ]] && { echo "ERROR: $CLAUDE_MD not found" >&2; exit 1; }
[[ ! -f "$MAP_FILE" ]] && { echo "ERROR: $MAP_FILE not found" >&2; exit 1; }

CLAUDE_MTIME=$(stat -f %m "$CLAUDE_MD")

# --- Drift check ---
drift_lines=()
while IFS= read -r line; do
    [[ "$line" != "§"* ]] && continue
    [[ "$line" != *"|"* ]] && continue

    section=$(echo "$line" | awk -F'|' '{print $1}' | sed 's/ *$//')
    companion=$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^ *//;s/ *$//')
    companion="${companion/#\~/$HOME}"

    if [[ ! -e "$companion" ]]; then
        drift_lines+=("- $section | \`$companion\` | **MISSING** (listed in map but not on disk)")
        continue
    fi

    comp_mtime=$(stat -f %m "$companion")
    if (( CLAUDE_MTIME > comp_mtime )); then
        diff=$((CLAUDE_MTIME - comp_mtime))
        newer="CLAUDE.md"
    else
        diff=$((comp_mtime - CLAUDE_MTIME))
        newer="companion"
    fi

    if (( diff > DRIFT_THRESHOLD_SEC )); then
        days=$((diff / 86400))
        drift_lines+=("- $section | \`$companion\` | ${days}d apart, $newer is newer")
    fi
done < "$MAP_FILE"

# --- Freshness check ---
stale_lines=()
current_section=""
while IFS= read -r line; do
    if [[ "$line" =~ ^##\ ([0-9]+\.\ .+) ]]; then
        current_section="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ Last\ reviewed:\ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        review_date="${BASH_REMATCH[1]}"
        review_epoch=$(date -j -f "%Y-%m-%d" "$review_date" "+%s" 2>/dev/null || echo 0)
        if (( review_epoch > 0 )); then
            age=$((NOW_EPOCH - review_epoch))
            if (( age > FRESHNESS_THRESHOLD_SEC )); then
                days_old=$((age / 86400))
                stale_lines+=("- §$current_section | last reviewed ${days_old}d ago")
            fi
        fi
    fi
done < "$CLAUDE_MD"

# --- Report ---
total=$(( ${#drift_lines[@]} + ${#stale_lines[@]} ))
if (( total > 0 )); then
    mkdir -p "$REMINDER_DIR"
    {
        echo "# CLAUDE.md review needed"
        echo ""
        if (( ${#drift_lines[@]} > 0 )); then
            echo "## Companion drift (>${DRIFT_THRESHOLD_DAYS}d apart)"
            echo ""
            for l in "${drift_lines[@]}"; do echo "$l"; done
            echo ""
        fi
        if (( ${#stale_lines[@]} > 0 )); then
            echo "## Stale sections (>${FRESHNESS_THRESHOLD_DAYS}d since review)"
            echo ""
            for l in "${stale_lines[@]}"; do echo "$l"; done
            echo ""
            echo "**How to review:** for each stale section, ask: is the rule still firing in real sessions? Is the triggering incident still relevant? Delete or merge if stale; bump \`Last reviewed\` if live."
            echo ""
        fi
        echo "Governed by \`CLAUDE_MAINTENANCE.md\` §§4, 7."
        echo ""
        echo "Delete this file to dismiss."
    } > "$REMINDER_FILE"
    echo "Issues: ${#drift_lines[@]} drift, ${#stale_lines[@]} stale. Wrote $REMINDER_FILE"
    exit 0
else
    [[ -f "$REMINDER_FILE" ]] && rm "$REMINDER_FILE"
    echo "Clean: no drift, no stale sections"
    exit 0
fi
