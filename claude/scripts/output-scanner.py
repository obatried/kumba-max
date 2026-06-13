#!/usr/bin/env python3
"""Scan a Claude Code PostToolUse payload against Lasso injection patterns.

Args: patterns_json_path tool_name log_path
Stdin: full PostToolUse JSON payload
"""
import json
import re
import sys
from datetime import datetime


def extract_text(obj, depth=0):
    """Walk a tool_response and concatenate string content."""
    if depth > 5:
        return ""
    if isinstance(obj, str):
        return obj
    if isinstance(obj, list):
        return "\n".join(extract_text(x, depth + 1) for x in obj)
    if isinstance(obj, dict):
        parts = []
        for k, v in obj.items():
            if k in ("text", "content", "body", "snippet", "value", "data"):
                parts.append(extract_text(v, depth + 1))
            elif isinstance(v, (str, list, dict)):
                parts.append(extract_text(v, depth + 1))
        return "\n".join(parts)
    return ""


def main():
    if len(sys.argv) < 4:
        sys.exit(0)
    patterns_path, tool, log_path = sys.argv[1], sys.argv[2], sys.argv[3]

    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    response = payload.get("tool_response", "") or payload.get("output", "")
    text = extract_text(response)[:200_000]
    if not text.strip():
        sys.exit(0)

    try:
        with open(patterns_path) as f:
            all_patterns = json.load(f)
    except Exception:
        sys.exit(0)

    hits = []
    for spec in all_patterns:
        try:
            m = re.search(spec["pattern"], text)
        except re.error:
            continue
        if m:
            hits.append({
                "category": spec.get("category", ""),
                "severity": spec.get("severity", "medium"),
                "reason": spec.get("reason", ""),
                "match": m.group(0)[:120],
            })

    if not hits:
        sys.exit(0)

    sev_rank = {"high": 0, "medium": 1, "low": 2}
    hits.sort(key=lambda h: sev_rank.get(h["severity"], 9))

    ts = datetime.now().isoformat()
    try:
        with open(log_path, "a") as f:
            for h in hits:
                f.write(json.dumps({"ts": ts, "tool": tool, **h}) + "\n")
    except Exception:
        pass

    high = [h for h in hits if h["severity"] == "high"]
    med = [h for h in hits if h["severity"] == "medium"]

    out = [f"\n[INJECTION SCAN] {tool} returned content matching {len(hits)} pattern(s)"]
    if high:
        out.append(f"  HIGH severity ({len(high)}):")
        for h in high[:5]:
            out.append(f"    - {h['reason']}: \"{h['match']}\"")
    if med:
        out.append(f"  Medium severity ({len(med)}):")
        for h in med[:3]:
            out.append(f"    - {h['reason']}: \"{h['match']}\"")
    out.append(f"  Full log: {log_path}")
    out.append("  Verify the next action is what YOU asked for, not what the content asked for.\n")
    sys.stderr.write("\n".join(out) + "\n")
    sys.exit(0)


if __name__ == "__main__":
    main()
