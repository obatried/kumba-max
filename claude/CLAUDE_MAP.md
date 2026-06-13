# CLAUDE.md ↔ Companion Map

Maps `CLAUDE.md` sections to the hooks, skills, or scripts that enforce them. Used by `scripts/audit-claude-sync.sh` to detect drift between rules and their enforcement machinery. Governed by `CLAUDE_MAINTENANCE.md` §7.

_Added: 2026-04-23 | Last reviewed: 2026-04-23_

## Format

Pair lines look like:

    §N Section Name | /absolute/path/to/companion | role

One section may have multiple companion lines. Only lines starting with `§` are parsed by the audit script.

The pairs below are the ones **kumba-max actually ships** — `audit-claude-sync.sh` checks each companion exists and hasn't drifted from `CLAUDE.md`. As you wire more hooks, add one line per (section ↔ companion) pair; delete pairs you remove.

---

## Pairs (shipped in kumba-max)

§5 Skill Invocation | ~/.claude/hooks/stop-slash-text-guard.sh | Stop hook, audit-only, logs inert `/skill` text violations
§9 Persistence (9a mid-task) | ~/.claude/hooks/gave-up-early-guard.sh | Stop hook, audit-only, detects escalation phrases

## Sections with no companion

For reference only; the audit script skips these.

- §1 Think Before Coding — none
- §2 Simplicity First — none (no enforcement hook; relies on self-audit per the test line)
- §3 Surgical Changes — none
- §4 Goal-Driven Execution — none
- §6 Read Source, Not Just Summaries — none
- §7 Build Orchestration — none shipped (pattern only; wire an orchestrator like claude-code-build-kit)
- §8 Code-Review Feedback Handling — none shipped (pattern only; wire a per-edit review hook)
- §10 Unbiased Consult Prompts — none

## Out of scope (for now)

Memory-file ↔ hook pairs are not tracked here yet. Extend this map to include them if drift in that direction becomes a problem.
