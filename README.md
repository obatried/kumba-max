# kumba-max

**A complete, loaded Claude Code setup in one `git clone` — every layer that makes Claude Code dramatically better, vendored together and explained in plain English.**

Governance that keeps your rulebook from rotting, a real memory with keyword search, a security layer against prompt-injection, a self-correcting `/learn` loop, coding-discipline hooks, and a confidence-check skill — all pre-composed so they actually work together, installed by one script that backs up your config first.

This is the **full** bundle. If you just installed Claude Code and want the gentle on-ramp, start with [**kumba-min**](https://github.com/obatried/kumba-min) instead — four files, fully explained, nothing overwhelming. Come here when you know what each piece is for.

> **Where this comes from.** kumba-max vendors several standalone open-source projects into one drop-in package, so you don't have to install and reconcile six installers by hand. Each layer is its own repo if you want the deep docs: [total-recall](https://github.com/obatried/total-recall) (memory), [claude-shield](https://github.com/obatried/claude-shield) (security), [recursive-learn](https://github.com/obatried/recursive-learn) (`/learn`), [oba-claude](https://github.com/obatried/oba-claude) (CLAUDE.md governance), [claude-conf](https://github.com/obatried/claude-conf) (`/conf`), and [claude-code-build-kit](https://github.com/obatried/claude-code-build-kit) (the `/build` orchestrator — *not* bundled here; see §7/§8 note below). The injection-pattern library is from [Lasso Security](https://github.com/lasso-security/claude-hooks) — see [NOTICE.md](./NOTICE.md).

## The layers

| Layer | What it gives you | Source |
|---|---|---|
| **Governance** | A 10-section `CLAUDE.md` of coding principles + a maintenance policy, companion map, and worked examples that keep it from rotting as it grows. | oba-claude |
| **Memory** | A tidy file-based memory with **keyword search (SQLite FTS5/BM25)**, automatic recall at point-of-need, duplicate detection, and write-discipline so notes stay findable. | total-recall |
| **Security** | Prompt-injection scanning on everything Claude reads from the web/email/Slack, a 96-pattern library, session-taint tracking, and friction-free gates on risky sends. | claude-shield |
| **Self-correction** | A `/learn` loop that turns a mistake into a hook so it can't recur, surfaces playbooks at point-of-need, and injects a verify-first checklist each session. | recursive-learn |
| **Discipline** | Hooks enforcing "don't print a dead `/skill`" (§5) and "don't give up prematurely" (§9), plus a byte-budget guard that flags bloated docs. | build-kit + live |
| **`/conf`** | A confidence-check skill: before a non-trivial edit, Claude rates each change High/Med/Low and surfaces what to verify first. | claude-conf |

Every file is explained — what it is, why you want it, how to turn it off — in **[WHATS_INSIDE.md](./WHATS_INSIDE.md)**.

## Install

```bash
# Install Claude Code if you haven't
npm install -g @anthropic-ai/claude-code

git clone https://github.com/obatried/kumba-max
cd kumba-max
./install.sh
```

The installer **backs up your existing `~/.claude` first**, then copies in the files, writes the memory-engine config, builds the search index, seeds the learn-loop state, and merges permissions + every hook into `settings.json` (idempotent — safe to re-run, never clobbers config or notes you already have).

**Requirements:** `jq`, `python3` (with FTS5 — standard on macOS/Linux), `git`, `bash`. The installer checks all of them and stops with a clear message if one's missing.

Then **restart Claude Code** and read **[GETTING_STARTED.md](./GETTING_STARTED.md)**.

## A note on §7 and §8 of CLAUDE.md

The `CLAUDE.md` describes a **build orchestrator** (§7) and a **per-edit code-review hook** (§8) as *patterns*. kumba-max does **not** ship that machinery — it's heavier and opinionated. If you want the actual `/build` orchestrator + Codex review wiring, see [claude-code-build-kit](https://github.com/obatried/claude-code-build-kit). The sections stay because the *discipline they describe* is worth keeping in front of Claude even without the tooling.

## Turning things off

Nothing here is load-bearing for Claude Code itself — it's all additive. Don't want a layer? WHATS_INSIDE has the one-line off-switch for each. Or:

```bash
./uninstall.sh   # removes hooks + their settings entries + the engine; leaves your notes + state
```

For a full clean slate, restore the `~/.claude.bak.*` backup the installer made.

## License

MIT (this bundle). Vendored components keep their own licenses — all MIT. The injection-pattern data is MIT, originally by Lasso Security; see [NOTICE.md](./NOTICE.md).
