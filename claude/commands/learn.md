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

## Step A2 — Structured-review fold-back (ONLY if a graded review returned named defects this session)

Skip entirely unless an external review handed back **named, located** defects this session — an automated grader, a human PR/code review, a CI gate, or a QA report. No such verdict → skip silently.

A structured verdict is **proof a playbook/checklist may be incomplete**, so the job is to ACT, not just note. The failure this step exists to prevent: *summarizing the headline lesson while the individual named defects never make it into the checklist* ("we learned but didn't do it"). So:
- **Walk the FULL defect list, not the headline.** For EACH clearly-defined defect, do one of: (a) fold a compact preventive rule into the relevant pre-submit checklist/playbook (refresh an existing line, don't duplicate); or (b) skip it *explicitly* as one-off / ambiguous / not-preventable-before-submit / already-covered. Mechanizable (regex / path / metadata check) → the checklist's machine-checks; judgment-only → one sharp line.
- **Reconcile before ending:** every defect must be accounted for — added, refreshed, already-covered, or deliberately skipped. Report the count in the Output block.
- **Fold into the workflow's own pre-submit home** — the playbook or checklist that governs that workflow, not a global note.
- **Don't over-build:** the external grader is the source of truth — the durable rule is procedural ("run it before submit, fix, re-run until clean, fold back any new defect class"). Build a local scripted check only for the cheap, recurring, deterministic subset; never clone the grader wholesale (it drifts from their real criteria and gives false-green confidence).

## Step B — Mistake → minimal (no journal, no taxonomy)

Was there a notably-wrong **action** this session (not just an imperfect phrasing)? If no, skip this step entirely.

**Also — user corrections.** Did the user push back on or correct your behavior this session (incl. soft signals: "actually", "instead", "hmm", or re-stating an ask they already made)? If it's a correction worth not repeating, generalize its ROOT (not the surface complaint), then find its **canonical owner and EDIT that** — a CLAUDE.md section, the playbook that runs the workflow, or project/topic memory. Workflow mechanics (steps, timings) belong in the playbook, not a parallel global note. Write a new `feedback_*.md` only when no owner exists. Judgment, not an exhaustive per-message audit.

**Feedback-as-debt.** Standalone `feedback_*` notes are the part of a memory corpus most likely to become dead weight — a note with no detectable trigger can never auto-surface, so it's write-only: it costs retrieval precision and never pays it back. So: (1) **default HARD to editing a canonical owner** (CLAUDE.md / playbook / project memory) over spawning a new note; (2) a new `feedback_*.md` is admissible only if it has a **detectable trigger** you can wire to an `inform_*` spec (else it can't fire and is debt on creation); (3) if the same correction family recurs ~3+ times, **stop writing notes — fix the root mechanism** (a hook, a CLAUDE.md rule, or the workflow itself). A note that can't fire isn't a memory, it's litter.

If yes, classify it — **by invariance and harm FIRST, detectability second.** Detectability (can you write an exact path or command pattern for it?) only decides how *reliably* a mechanism can fire; it does NOT earn the strongest mechanism. A regex match means you *can* hard-block, not that you *should*.

**A hard guard (`deny_*` in `guard-specs.json`) is a global safety rail, not a strong memory** — it is permanent, applies in every project and session, and escaping it means hand-editing JSON. So it is admissible ONLY when you can name the **harm class** it prevents: `data_loss`, `security`, `environment_breakage`, or `tool_semantics` (a tool/shell that silently does the wrong thing). **If the best label you can give the correction is `preference`, `style`, `workflow`, or `pacing` → it gets NO hard guard, even if it's perfectly detectable.** Sanity test: a hard guard's `reason` must read as a timeless rule on its own; if you can't write it without "the user said so this once", it is a contextual call, not an invariant. (A cautionary case: a one-session "stop pacing yourself" instruction was regex-detectable, so it ossified into a forever-global deny that later fought the user's own intent and had to be torn out by hand. Detectable ≠ worth enforcing forever.)

Then route by mechanism:
- **Harm-class invariant + detectable** → **install the hard guard NOW**, phrased timelessly (kill-the-browser, `rm -rf /`, a shell idiom that returns a false-green exit code). Append a spec to `~/.claude/state/guards/guard-specs.json`; the `learn-guard.sh` PreToolUse hook reads it and DENIES the matching call.
  ```bash
  jq '. += [{"type":"deny_write_path","path":"/ABS/PATH","reason":"why + what to do instead"}]' \
     ~/.claude/state/guards/guard-specs.json > ~/.claude/state/guards/.gs.$$ \
     && mv ~/.claude/state/guards/.gs.$$ ~/.claude/state/guards/guard-specs.json
  # command form: {"type":"deny_bash_regex","pattern":"<portable, ANCHORED ERE>","reason":"..."}
  ```
  Use the **absolute** path (exact match); keep regexes **portable and anchored** so they can't over-block.
- **Detectable but preference / workflow / pacing / style** → do **NOT** hard-block. Bind an `inform_*` surface (Step A's mechanism) so it *reminds* at the action point and stays **overridable in the moment**, and/or home it in the relevant project's memory. A reversible preference must never require editing JSON to escape.
- **Fuzzy + universal** (about how you reason about any claim or state — applies to any session regardless of what's being worked on) → **sharpen the single matching line** in `~/.claude/state/recursive-learning/verify-preflight.md`. Keep that file to **~5 lines, one sentence each, zero project examples** — sharpen the existing line, never add a per-incident bullet, never let a line grow past one sentence. Be honest: this is salience-only (less likely, not impossible).
- **Fuzzy + project/tool-scoped** (it names a specific product, tool, file format, or workflow) → it belongs in that project's memory or the relevant `reference_*` playbook, which prompt-time recall already surfaces on mention. That's **Step A's job — deepen the playbook there.** Do **NOT** copy it into the global preflight: that is exactly what bloats it — a lossy duplicate of a lesson already homed, broadcast to every unrelated session.

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
- Review fold-back: N folded / M already-covered / K skipped (reason) | n/a (no graded review)
- Mistake → guard installed: <path/pattern> | salience line sharpened | none
- Memory maintenance: M merges applied (date) | K pending — surfaced | none pending
- Still open: one line | nothing
```

Then append one JSON line to your run log (`~/.claude/state/learn/learn-runs.jsonl`) — run it as a **single standalone command**, not bundled with `mkdir` or other steps (a multi-step blob can re-trigger a permission prompt even when Bash is allow-listed):
`{ts, session, playbooks_captured, guard_installed, salience_sharpened, review_folded}`
