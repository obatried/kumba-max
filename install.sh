#!/usr/bin/env bash
# kumba-max installer — the full, loaded Claude Code baseline.
#
# Installs, in order:
#   1. CLAUDE.md (10 governance sections + a memory section) + governance docs
#   2. all hooks, the memory-search engine, the /conf + /learn skills, security data
#   3. a tidy file-based memory with keyword search (FTS5/BM25), recall + dedup
#   4. the learn-loop + capped-files state seeds
#   5. permissions + every hook wired into settings.json
#
# Idempotent. Backs up your existing ~/.claude before touching anything.
# Re-running is safe. Your own notes and accumulated state are never overwritten.

set -euo pipefail

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERR:\033[0m %s\n' "$*" >&2; exit 1; }

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$KIT_DIR/claude"
[ -d "$SRC" ] || die "kit dir not found: $SRC"

CLAUDE="$HOME/.claude"
HOOKS="$CLAUDE/hooks"
SETTINGS="$CLAUDE/settings.json"
CLAUDEMD="$CLAUDE/CLAUDE.md"
MEM_DIR="$CLAUDE/memory"
ENGINE="$CLAUDE/memory-engine"
CONFIG_DIR="$HOME/.config/total-recall"
CONFIG="$CONFIG_DIR/config"
DB_PATH="$HOME/.cache/total-recall/index.db"
STATE="$CLAUDE/state"

# ─── Deps ───────────────────────────────────────────────────────────────────
for c in jq python3 git bash; do
  command -v "$c" >/dev/null 2>&1 || die "Missing required command: $c"
done
python3 - <<'PY' || die "Your python3's sqlite3 lacks FTS5 (needed for memory search). Try a different python3 (brew install python)."
import sqlite3, sys
try: sqlite3.connect(":memory:").execute("CREATE VIRTUAL TABLE t USING fts5(x)")
except Exception: sys.exit(1)
PY

# ─── Backup ─────────────────────────────────────────────────────────────────
TS=$(date +%Y%m%d-%H%M%S)
if [ -d "$CLAUDE" ]; then
  BACKUP="$CLAUDE.bak.$TS"
  say "Backing up existing ~/.claude → $BACKUP"
  cp -R "$CLAUDE" "$BACKUP"
fi

mkdir -p "$HOOKS" "$CLAUDE/scripts" "$CLAUDE/data" "$CLAUDE/commands" "$ENGINE" \
         "$CLAUDE/analytics" "$STATE/guards" "$STATE/recursive-learning" \
         "$CONFIG_DIR" "$(dirname "$DB_PATH")"

# ─── Files (overwrite our own; never user data) ─────────────────────────────
say "Installing hooks, engine, skills, governance, security data..."
cp "$SRC/hooks/"*.sh        "$HOOKS/"
cp "$SRC/scripts/"*         "$CLAUDE/scripts/"
cp "$SRC/data/"*            "$CLAUDE/data/"
cp "$SRC/commands/"*        "$CLAUDE/commands/"
cp "$SRC/memory-engine/"*   "$ENGINE/"
cp "$SRC/CLAUDE_MAINTENANCE.md" "$SRC/CLAUDE_MAP.md" "$SRC/EXAMPLES.md" "$CLAUDE/"
chmod +x "$HOOKS/"*.sh "$CLAUDE/scripts/"*.sh "$ENGINE/"*.py "$ENGINE/total-recall" 2>/dev/null || true

# ─── CLAUDE.md ──────────────────────────────────────────────────────────────
MARK_OPEN="<!-- kumba-max:start -->"; MARK_CLOSE="<!-- kumba-max:end -->"
SENTINEL="<!-- kumba-max -->"   # present whether copied whole or appended
if [ ! -f "$CLAUDEMD" ]; then
  say "Installing ~/.claude/CLAUDE.md"
  cp "$SRC/CLAUDE.md" "$CLAUDEMD"
elif grep -qF "$SENTINEL" "$CLAUDEMD" 2>/dev/null; then
  say "CLAUDE.md already has the kumba-max content — skipping."
else
  warn "You already have a ~/.claude/CLAUDE.md — appending the kumba-max sections under a marked block (review + trim; delete the block to undo)."
  { printf '\n%s\n' "$MARK_OPEN"; cat "$SRC/CLAUDE.md"; printf '%s\n' "$MARK_CLOSE"; } >> "$CLAUDEMD"
fi

# ─── Memory folder + aliases ────────────────────────────────────────────────
if [ ! -d "$MEM_DIR" ] || [ -z "$(ls -A "$MEM_DIR" 2>/dev/null)" ]; then
  say "Seeding memory template into $MEM_DIR"
  mkdir -p "$MEM_DIR"; cp -R "$SRC/memory/." "$MEM_DIR/"
else
  say "~/.claude/memory already has files — leaving them as-is."
  [ -f "$MEM_DIR/.allowed-indexes" ] || cp "$SRC/memory/.allowed-indexes" "$MEM_DIR/.allowed-indexes"
fi
if [ ! -f "$MEM_DIR/.aliases" ]; then
  cat > "$MEM_DIR/.aliases" <<'EOF'
# Synonym groups, one per line (comma-separated). A query term in a group also searches
# the others, bridging "different words, same meaning" that keyword search can't. Examples:
# car, automobile, vehicle
# pay, payment, billing, invoice
EOF
fi

# ─── Memory engine config ───────────────────────────────────────────────────
if [ ! -f "$CONFIG" ]; then
  say "Writing memory config → $CONFIG"
  cat > "$CONFIG" <<EOF
# total-recall config (KEY=VALUE). Env vars override these at runtime.
TR_HOME="$ENGINE"
MEM_DIR="$MEM_DIR"
DB_PATH="$DB_PATH"
ALLOWED_INDEXES="$MEM_DIR/.allowed-indexes"
ALIASES="$MEM_DIR/.aliases"
INDEX_FILE=MEMORY.md
# --- write discipline ---
# ENFORCE_HOME=0      # set to 0 to stop requiring a 'home:' field on new notes
# --- recall tuning (UserPromptSubmit) ---
# RECALL_AVG=-3.0
# RECALL_STRONG=-18
# RECALL_RATIO=0.5
# RECALL_CAP=6
# --- dedup tuning (PreToolUse Write) ---
# DEDUP_STRONG=-18
# DEDUP_RATIO=0.6
EOF
else
  say "~/.config/total-recall/config already exists — leaving it."
fi

# ─── Learn-loop state (seed only if absent) ─────────────────────────────────
[ -f "$STATE/guards/guard-specs.json" ]  || cp "$SRC/state/guards/guard-specs.json"  "$STATE/guards/guard-specs.json"
[ -f "$STATE/guards/inform-specs.json" ] || cp "$SRC/state/guards/inform-specs.json" "$STATE/guards/inform-specs.json"
[ -f "$STATE/recursive-learning/verify-preflight.md" ] \
  || cp "$SRC/state/recursive-learning/verify-preflight.md" "$STATE/recursive-learning/verify-preflight.md"

# ─── Capped-files registry (size guard) ─────────────────────────────────────
if [ ! -f "$STATE/capped-files.tsv" ]; then
  say "Seeding capped-files registry (size guard for lean docs)"
  cat > "$STATE/capped-files.tsv" <<EOF
# <glob>  <byte-budget>  [max-line-bytes]   — capped-files-check warns when a file is over.
# Lines starting with # are ignored. Tune budgets to taste; ~ expands to \$HOME.
~/.claude/CLAUDE.md            20000   600
~/.claude/memory/MEMORY.md     25000   800
EOF
fi

# ─── Build the search index ─────────────────────────────────────────────────
say "Building memory search index..."
TOTAL_RECALL_CONFIG="$CONFIG" python3 "$ENGINE/index.py" >/dev/null 2>&1 \
  || warn "index build did not complete — run: TOTAL_RECALL_CONFIG=$CONFIG python3 $ENGINE/index.py"

# ─── settings.json ──────────────────────────────────────────────────────────
SETTINGS_MARKER="total-recall-recall.sh"
if [ ! -f "$SETTINGS" ]; then
  say "Installing ~/.claude/settings.json"
  cp "$SRC/settings.json" "$SETTINGS"
elif grep -qF "$SETTINGS_MARKER" "$SETTINGS" 2>/dev/null; then
  say "Kit hooks already wired in settings.json — skipping merge."
else
  say "Merging permissions + hooks into existing settings.json..."
  TMP=$(mktemp)
  jq -s '
    .[0] as $e | .[1] as $t |
    $e
    | .permissions.allow = (((($e.permissions.allow) // []) + (($t.permissions.allow) // [])) | unique)
    | .permissions.deny  = (((($e.permissions.deny)  // []) + (($t.permissions.deny)  // [])) | unique)
    | .permissions.ask   = (((($e.permissions.ask)   // []) + (($t.permissions.ask)   // [])) | unique)
    | .hooks.SessionStart    = ((($e.hooks.SessionStart)    // []) + (($t.hooks.SessionStart)    // []))
    | .hooks.UserPromptSubmit = ((($e.hooks.UserPromptSubmit) // []) + (($t.hooks.UserPromptSubmit) // []))
    | .hooks.PreToolUse      = ((($e.hooks.PreToolUse)      // []) + (($t.hooks.PreToolUse)      // []))
    | .hooks.PostToolUse     = ((($e.hooks.PostToolUse)     // []) + (($t.hooks.PostToolUse)     // []))
    | .hooks.Stop            = ((($e.hooks.Stop)            // []) + (($t.hooks.Stop)            // []))
  ' "$SETTINGS" "$SRC/settings.json" > "$TMP" \
    && jq -e . "$TMP" >/dev/null \
    && mv "$TMP" "$SETTINGS" \
    || { rm -f "$TMP"; die "settings.json merge failed — left your file untouched."; }
fi

say "Done."
echo
echo "Next:"
echo "  1. RESTART Claude Code (hooks + CLAUDE.md load at session start)."
echo "  2. Optional — enable Gmail/Calendar auto-approval by setting your own addresses:"
echo "       echo 'export CLAUDE_SHIELD_SELF_EMAILS=\"you@example.com\"' >> ~/.zshrc"
echo "  3. Try memory search:  $ENGINE/total-recall \"something in your notes\""
echo "  4. Read WHATS_INSIDE.md — every layer, what it does, how to turn it off."
[ -n "${BACKUP:-}" ] && echo && echo "Your previous ~/.claude is backed up at: $BACKUP"
