Recursive learning pass. Its job: turn what just happened into durable behavior change for next time — **primarily by capturing reusable playbooks so a problem solved once is never re-solved or re-explained**, and secondarily by hard-stopping a detectable mistake from recurring. Run at the end of a substantive session, or when something notable happened (you explained a procedure, the agent burned real time finding a working path, a failure/recovery, repeated pushback).

**Scope discipline (read this first — it is the whole point).** This skill used to be a mistake-auditing journal: it re-read every claim, sorted misses into families, ran an escalation ladder, and grew a lesson registry. That produced *documentation, not behavior change* — a note in a file never changed the next session, because the only things that carry over are (1) what gets re-injected into context and (2) what a hook enforces. So this skill now does just two things well: **capture playbooks** and, when a real mistake recurs, **install a guard or sharpen the one salience line.** If you feel the urge to classify a family, update a registry, or write a per-claim audit table — STOP. That was the old shape. Keep this skill small forever.

**Forward-only (read this too).** This skill reflects on the session that *just happened* — what you learned, fixed, or got corrected on, while it's in front of you. It does **NOT** mine, re-read, or audit past transcripts to score yourself. A backward audit-sample is a trap: it manufactures activity, costs a sweep every run, and measures the wrong axis. Learning happens going forward, not by grading history.

---

## Step 0 — Gate (don't run on nothing)

Run only if the session was substantive — judge qualitatively, don't tally tool calls: you explained how to do something, the agent spent real effort finding a working path, a notable failure/recovery happened, or there was real pushback. If none apply, output `/learn: skipped (non-substantive session)` and stop.

## Step A — Capture playbooks (THE CORE)

Ask: **did I work out HOW to do something this session that I'd otherwise have to re-figure-out next time — or did the user explain a procedure they should never have to explain again?** Tells — I spent more than a call or two discovering a method, hit a "that path was blocked, this one worked" moment, found a non-obvious auth/tool/navigation path, or the user walked me through steps.

**Capture bar (gated — do NOT capture trivia).** Save only when ONE holds: the user explained it, OR it cost real time / dead-ends, OR the user said "save this." Everything else: skip.

For each that clears the bar, write or refresh a `reference_*.md` playbook in your memory/playbook dir:
- **Index by TASK SHAPE, not the incident.** The title and any index pointer must read like the words I'd reach for next time — "pull the meeting notes for a call", "get the value needed to do a billing write op" — NOT "that thing on 6/3". This is what makes retrieval actually fire.
- Record the **working path** (exact commands / clicks / tool sequence) AND the **dead-ends to skip**, so next time's re-discovery cost is zero.
- If a playbook already covers it, **deepen that one** — don't spawn a duplicate.
- **Wire it to fire at point-of-need (the retrieval upgrade — do this or the file stays inert).** A playbook only changes behavior if it gets re-injected at the moment it's needed. Prompt-time recall covers the case where my *prompt* keyword-matches. But if the playbook applies at a **mid-task action** — about to run a command, write to a path, or call a tool — there's no prompt to match, so bind it directly: if the playbook has a *detectable trigger* (a Bash command pattern, a file-path pattern, or an exact tool name), append an `inform_*` spec to `~/.claude/state/guards/inform-specs.json`. The `mem-surface.sh` PreToolUse hook then surfaces this playbook the instant I reach for that action next time — no keyword luck required. This is the inform-side twin of Step B's deny guard.
  ```bash
  jq '. += [{"type":"inform_on_bash_regex","pattern":"<anchored ERE>","memory":"reference_xxx.md","note":"one-line why/what"}]' \
     ~/.claude/state/guards/inform-specs.json > ~/.claude/state/guards/.is.$$ \
     && mv ~/.claude/state/guards/.is.$$ ~/.claude/state/guards/inform-specs.json
  # other types: {"type":"inform_on_path_regex","path_regex":"<ERE>",...}  |  {"type":"inform_on_tool","tool":"<exact tool_name>",...}
  ```
  `memory` is the file path RELATIVE to your memory dir. Prefer binding to an **early** action in the workflow (a first read/list), so the runbook lands *before* the consequential write — the hook informs, it doesn't block. No detectable trigger? Skip this; prompt-time recall is the only carrier for purely conversational playbooks. (`inform_on_tool` only fires for tools `mem-surface` is registered on — `Write`/`Edit`/`MultiEdit`/`Bash` by default; to surface on another tool, add its exact name to the `mem-surface` matcher in `settings.json` first.)

## Step B — Mistake → minimal (no journal, no taxonomy)

Was there a notably-wrong **action** this session (not just an imperfect phrasing)? If no, skip this step entirely.

**Also — user corrections.** Did the user push back on or correct your behavior this session (incl. soft signals: "actually", "instead", "hmm", or re-stating an ask they already made)? If it's a correction worth not repeating, generalize its ROOT (not the surface complaint) into a rule in your memory dir — and check for an existing rule to refine before creating a duplicate. Judgment, not an exhaustive per-message audit.

If yes, classify the trigger's **detectability** — that decides whether you can actually prevent recurrence:
- **Detectable** (an exact file path you must not write, or a Bash command pattern you must not run) → **install a hard guard NOW**, on first identification. Append a spec to `~/.claude/state/guards/guard-specs.json`; the `learn-guard.sh` PreToolUse hook reads it and DENIES the matching call. This is the *only* level that genuinely makes a mistake "never again."
  ```bash
  jq '. += [{"type":"deny_write_path","path":"/ABS/PATH","reason":"why + what to do instead"}]' \
     ~/.claude/state/guards/guard-specs.json > ~/.claude/state/guards/.gs.$$ \
     && mv ~/.claude/state/guards/.gs.$$ ~/.claude/state/guards/guard-specs.json
  # command form: {"type":"deny_bash_regex","pattern":"<portable, ANCHORED ERE>","reason":"..."}
  ```
  Use the **absolute** path (exact match); keep regexes **portable and anchored** so they can't over-block.
- **Fuzzy** (a judgment call, no clean signature) → first decide **scope**. Is the lesson *universal* (about how you reason about any claim or state — applies to any session regardless of what's being worked on), or *project/tool-scoped* (it names a specific product, tool, file format, or workflow)?
  - **Universal** → **sharpen the single matching line** in `~/.claude/state/recursive-learning/verify-preflight.md`. Keep that file to **~5 lines, one sentence each, zero project examples** — sharpen the existing line, never add a per-incident bullet, never let a line grow past one sentence. Be honest: this is salience-only (less likely, not impossible).
  - **Project/tool-scoped** → it belongs in that project's memory or the relevant `reference_*` playbook, which prompt-time recall already surfaces on mention. That's **Step A's job — deepen the playbook there.** Do **NOT** copy it into the global preflight: that is exactly what bloats it — a lossy duplicate of a lesson already homed, broadcast to every unrelated session.

## Step C — Close the dedup loop (every run — cheap)

Capture without maintenance just grows an unmaintained pile: the corpus only grows, and retrieval degrades as it bloats. This step is the cheap maintenance half. It is surface-and-propose only — you decide, then apply carefully.

If you run a periodic consolidation pass (e.g. a weekly job that clusters near-duplicate memories and writes merge proposals), this is where you consume it: read the newest proposal, surface ONE line — *"M pending memory merges (+K prune candidates) — apply now?"* — and only on a yes, apply each merge with discipline:
- Back up every touched file; never delete irreversibly — move superseded files to an `archive/` dir.
- **Verify each merge preserves all nuance + every cross-link before applying.** A second read-only review pass (a different model is ideal) is cheap here; use it, but spot-verify its concrete file claims (a reviewer can fabricate line facts). Never auto-merge on a digest's say-so alone.
- Pick the survivor by inbound-reference count; repoint inbound refs; collapse duplicate index lines.

No consolidation pass yet? Skip this step. Keep it conservative: surface similarity ≠ duplication; when a cluster is genuinely two lessons, leave it.

## Output

```
/learn
- Playbooks captured/refreshed: N (slug — one line each) | none
- Mistake → guard installed: <path/pattern> | salience line sharpened | none
- Memory maintenance: M merges applied (date) | K pending — surfaced | none pending
- Still open: one line | nothing
```

Then append one JSON line to your run log (`~/.claude/state/learn/learn-runs.jsonl`):
`{ts, session, playbooks_captured, guard_installed, salience_sharpened}`
