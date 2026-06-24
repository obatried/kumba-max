#!/bin/bash
# Shared helper for the total-recall memory hooks (memory-autoindex.sh, memory-home-required.sh).
#
# extract_fm_scalar <key>  — reads YAML-ish frontmatter on STDIN, prints the value of
#   <key> accepting EITHER a top-level "key:" OR a "metadata.<key>:" (indented under a
#   `metadata:` block). Surrounding single/double quotes are stripped. Prints nothing if
#   the key is absent. Exits on the first match.
#
#   Some Claude Code setups run a frontmatter canonicalizer that rewrites freshly-written
#   memory files, NESTING home: (and other fields) under an indented `metadata:` block.
#   A plain /^home:/ anchor misses those — so this accepts both shapes. (Tracked via an
#   in_metadata flag rather than a loose /^[[:space:]]*home:/ that would match any
#   indented home anywhere in the frontmatter.)
#
# Usage:
#   from a file:   val=$(extract_fm_scalar home < "$file")
#   from a string: val=$(printf '%s' "$content" | extract_fm_scalar home)
extract_fm_scalar() {
  awk -v key="$1" '
    function clean(s){ sub(/^[[:space:]]+/,"",s); sub(/[[:space:]]+$/,"",s);
      if (s ~ /^".*"$/ || s ~ /^'"'"'.*'"'"'$/) s=substr(s,2,length(s)-2); print s; exit }
    /^---[[:space:]]*$/ { if(!in_fm){in_fm=1;next} exit }
    !in_fm { next }
    /^metadata:[[:space:]]*$/ { in_metadata=1; next }
    /^[^[:space:]#][^:]*:/ { in_metadata=0 }
    $0 ~ ("^" key ":[[:space:]]*") { sub("^[^:]+:[[:space:]]*",""); clean($0) }
    in_metadata && $0 ~ ("^[[:space:]]+" key ":[[:space:]]*") { sub("^[[:space:]]+[^:]+:[[:space:]]*",""); clean($0) }
  '
}
