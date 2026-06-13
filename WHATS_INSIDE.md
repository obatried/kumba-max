# What's Inside

Every layer kumba-max installs, in plain English: **what it is**, **why you want it**, and **how to turn it off**. None of it is load-bearing for Claude Code — it's all additive, and every piece has an off-switch.

After install, files live under `~/.claude/` (your global Claude Code config). This repo is the source you copied them from. If you ever want the deep docs for a layer, each one is its own upstream repo (linked per section).

---

## Layer 1 — The rulebook & its governance

### `CLAUDE.md` → `~/.claude/CLAUDE.md`
**What it is.** A markdown file loaded into *every* session. 10 sections of coding discipline (think before coding, simplicity, surgical changes, goal-driven execution, skill invocation, read source not summaries, build orchestration, code-review handling, persistence, unbiased consults) plus a **Memory** section that teaches Claude how to write findable notes.

**Why you want it.** Standing instructions are the single highest-leverage setup you can do — they change Claude's defaults across everything, so it stops over-building, over-editing, and guessing confidently. Each section ends with a "The test:" line so Claude (and you) can self-audit.

**How to turn it off.** Edit or delete any section — it's just markdown. To remove kumba-max's block from a `CLAUDE.md` you already had, delete the text between `<!-- kumba-max:start -->` and `<!-- kumba-max:end -->`.

> **§7 and §8** describe a build orchestrator and a code-review hook as *patterns* — that machinery is **not** shipped here (see the README note). The discipline is worth keeping in front of Claude regardless.

### `CLAUDE_MAINTENANCE.md`, `CLAUDE_MAP.md`, `EXAMPLES.md` → `~/.claude/`
**What they are.** The anti-rot system for your rulebook. *Maintenance* is the policy for editing `CLAUDE.md` (every section earns rent, ≤10 sections, dated, no silent conflicts). *Map* lists which hook/skill enforces which section. *Examples* holds the long ✅/❌ pairs so the rulebook itself stays a terse reference card.

**Why you want them.** A `CLAUDE.md` that grows unchecked becomes a graveyard Claude ignores. These keep it lean and current as you add rules over months. (Source: [oba-claude](https://github.com/obatried/oba-claude).)

**How to turn it off.** Ignore them — they're documentation, nothing executes. `CLAUDE_MAP.md` is a template; adjust its pair list to the hooks you actually run.

### `scripts/audit-claude-sync.sh` → `~/.claude/scripts/`
**What it is.** A script (run it weekly via cron/launchd) that flags two things: a section whose `Last reviewed:` date is >90 days old, and a companion hook that's drifted >30 days out of sync with `CLAUDE.md`. Writes a reminder file.

**Why you want it.** It's the active half of the governance — it nudges you to review stale rules instead of trusting they're still right.

**How to turn it off.** Don't schedule it. It does nothing unless you wire it into cron.

---

## Layer 2 — settings.json

### `settings.json` → `~/.claude/settings.json`
**What it is.** Controls **permissions** (what runs without asking) and **hooks** (scripts wired to events). The permissions ship hardened: quiet reads/edits/web-search auto-allow; a wide **deny** list blocks reading secrets (`.env`, `.ssh`, keychains, wallets) and dangerous shell (`rm -rf /`, `sudo`, `git push --force`, piping curl into a shell); everything else prompts. 18 of the 19 hook scripts below are pre-wired (`email-html-guard` ships unwired — it's opt-in; see Layer 4).

**Why you want it.** It's the safety floor — the only silent actions are ones that can't hurt you. The deny list is defense-in-depth against both mistakes and a prompt-injection that tries to read a secret or force-push.

**How to turn it off / adjust.** Edit the `allow`/`deny`/`ask` lists and the `hooks` blocks. Each hook's individual off-switch is in its section below. Never put anything that spends money or sends data in `allow`.

---

## Layer 3 — Memory (with keyword search)

Source: [total-recall](https://github.com/obatried/total-recall). Four parts that reinforce each other — capture, structure, discipline, retrieve.

### `memory/` → `~/.claude/memory/`
**What it is.** Your notes — plain markdown you own, seeded with a working example structure: `MEMORY.md` (the index loaded every session), `topics/` + `projects/` (domain indexes loaded on demand), leaf `*_example.md` notes (the facts), `.allowed-indexes` (valid filing targets), `.aliases` (synonym groups for search). Three tiers so hundreds of notes stay usable.

**Why you want it.** This is what stops you re-explaining your project and preferences every session.

**How to turn it off.** Delete the folder, or replace the `*_example.md` files with your own once you've seen the shape.

### `memory-engine/` → `~/.claude/memory-engine/`
**What it is.** The search engine: `index.py` builds a read-only SQLite **FTS5/BM25** index over your notes; `search.py` queries it; `stale.py` lists old, unused notes for review; `total-recall` is the CLI (`~/.claude/memory-engine/total-recall "query"`). No embeddings, no vector DB, no API key — just keyword search, and **it never modifies your notes** (the index is a throwaway cache).

**Why you want it.** "Write things down" is useless if you can't find them later. This makes every note searchable and is what the recall hook queries.

**How to turn it off.** Remove the memory hooks (below). The engine is inert without them; the CLI is opt-in.

### The five memory hooks → `~/.claude/hooks/`
| Hook | Event | What it does |
|---|---|---|
| `memory-home-required.sh` | before a note Write | **Blocks** a new note missing a `home:` or a real `description:`. Keeps notes findable. |
| `memory-autoindex.sh` | after a note write | Appends the note's one-line pointer to its index. Keeps `MEMORY.md` accurate, zero upkeep. |
| `total-recall-rebuild.sh` | session start + after memory writes | Rebuilds the search index in the background. |
| `total-recall-recall.sh` | every prompt | On a confident match, surfaces up to 2 relevant notes — *at point-of-need*, even if you forgot you saved them. Biases to silence. |
| `total-recall-dedup.sh` | before a note Write | **Blocks once** if the new note strongly overlaps an existing one, pointing you to edit instead. Re-issue to override. |

**How to turn it off.** Remove a hook's entry from `settings.json`, or set `ENFORCE_HOME=0` in `~/.config/total-recall/config` to keep everything but the home-guard. All five no-op if the config file is gone.

### `~/.config/total-recall/config` (written by the installer)
**What it is.** Tells the engine + hooks where your notes live (`MEM_DIR`), where the index goes (`DB_PATH`), and holds the (commented) recall/dedup tuning knobs. **How to turn it off.** Delete it (hooks no-op) or uncomment a tuning line to adjust precision.

---

## Layer 4 — Security (prompt-injection defense)

Source: [claude-shield](https://github.com/obatried/claude-shield). Zero workflow change in normal sessions.

### The scanner + taint tracker
- **`output-scanner.sh`** + **`scripts/output-scanner.py`** + **`data/injection-patterns.json`** — after every tool that returns outside content (web, email, Slack, Drive, browser), scans the response against **96 injection patterns** (Lasso Security's library, MIT — see [NOTICE.md](./NOTICE.md)). Logs hits and writes a warning; **never blocks** (a false-positive block would be worse). Catches "ignore previous instructions and…"-style steering.
- **`session-taint.sh`** — marks a session that has read attacker-controllable content, so the persistence-guard can be stricter afterward.

**Why you want them.** An agent that reads the web/your inbox can be *steered* by a malicious page or email. This surfaces that the instant it happens instead of letting it silently redirect Claude. ~30ms on red-tool calls, <1ms otherwise.

**How to turn it off.** Remove `output-scanner.sh` / `session-taint.sh` from the `PostToolUse` block in `settings.json`.

### The gates
- **`persistence-guard.sh`** — before edits to sensitive paths (settings, hooks, dotfiles, SSH/AWS/K8s creds), warns *if the session has read external content first*; otherwise auto-allows (you editing your own config is normal).
- **`gmail-approve.sh`** / **`calendar-approve.sh`** — auto-approve email *drafts*, self-sends, and solo calendar events; anything with other people falls through to a normal prompt. They only ever *reduce* friction. Set `CLAUDE_SHIELD_SELF_EMAILS="you@example.com"` to enable; unset, they no-op.
- **`email-html-guard.sh`** — *shipped but not wired by default* (it's opinionated: blocks plain-text / inline-styled email sends). Enable by adding it to the gmail matcher in `settings.json` if you want enforced HTML email.

**How to turn it off.** Remove the relevant matcher block from `PreToolUse`.

---

## Layer 5 — Self-correction (`/learn`)

Source: [recursive-learn](https://github.com/obatried/recursive-learn). Forward-only: it only reflects on the session you just had.

### `commands/learn.md` → `~/.claude/commands/learn.md`
**What it is.** The `/learn` skill. At the end of a session it (A) captures a reusable playbook for something you cracked, (B) turns a *detectable* mistake into a deny-guard so it can't recur (or sharpens the verify-first checklist for a fuzzy one), and (C) dedups against existing notes.

**Why you want it.** A lesson written in a file is documentation, not learning — nothing changes next session unless something re-surfaces it or a hook enforces it. `/learn` is built on exactly those two carriers.

**How to turn it off.** Delete `~/.claude/commands/learn.md` (you just lose the `/learn` command).

### The five learn hooks → `~/.claude/hooks/`
| Hook | Event | What it does |
|---|---|---|
| `learn-preflight.sh` | session start | Injects a ~5-line verify-first checklist (kept short on purpose). |
| `learn-trigger.sh` | prompt | When you signal you're wrapping up, nudges "consider `/learn`." Never blocks. |
| `learn-guard.sh` | before tool use | **Denies** a tool call matching a guard you installed via `/learn` after a real mistake. No-op until a spec exists. |
| `mem-surface.sh` | before tool use | Surfaces the playbook bound to a command/path/tool you're about to use. Inform-only. |
| `commit-on-red-guard.sh` | before Bash | Catches a `git commit` chained to a test so it fires even on red. Ships in **log mode** — flip to enforce after watching the log. |

**State seeds** (`~/.claude/state/guards/{guard-specs,inform-specs}.json`, `~/.claude/state/recursive-learning/verify-preflight.md`) start empty/minimal — `/learn` grows them. **How to turn off:** remove the hook entries from `settings.json`. The guard/inform hooks are total no-ops while their spec files are empty.

---

## Layer 6 — Discipline & a size guard

- **`stop-slash-text-guard.sh`** (`Stop`, audit-only) — logs when Claude ends a message by *typing* a `/command` instead of invoking it (enforces `CLAUDE.md` §5). Source: starter-kit.
- **`gave-up-early-guard.sh`** (`Stop`, audit-only) — logs when Claude uses "you'll have to do this manually"-style give-up language, with context (how many tools it tried, whether it consulted a second model), enforcing §9. Tune from the log, upgrade to blocking later. Source: build-kit.
- **`capped-files-check.sh`** (`SessionStart`) + **`state/capped-files.tsv`** — warns when a "lean" doc (your `CLAUDE.md`, `MEMORY.md`) bloats past a byte budget. Line-count caps get gamed; this checks bytes + longest single line. Seeded with two entries — tune the budgets, or add your own files.

**How to turn it off.** Remove the hook from `settings.json`. The size guard also no-ops if `capped-files.tsv` is absent.

---

## Layer 7 — `/conf` confidence check

### `commands/conf.md` → `~/.claude/commands/conf.md`
**What it is.** A skill you invoke (`/conf`) before a non-trivial edit. For each proposed change, Claude must answer: how confident (High/Med/Low + why), how it'd concretely implement it, and what would raise the confidence. Anything Med/Low surfaces a verification step instead of code. Source: [claude-conf](https://github.com/obatried/claude-conf).

**Why you want it.** LLMs are trained to sound confident. This turns hidden uncertainty into a visible punch list of what to verify first — much harder for the model to write "Low, I haven't read the file" than to silently ship a guess.

**How to turn it off.** Delete `~/.claude/commands/conf.md`.

---

## Quick off-switch reference

| Want to disable… | Do this |
|---|---|
| A single hook | Remove its line from the matching event block in `~/.claude/settings.json` |
| The home-guard only (keep auto-filing) | `ENFORCE_HOME=0` in `~/.config/total-recall/config` |
| All memory hooks | Delete `~/.config/total-recall/config` (they no-op) |
| Gmail/calendar auto-approval | Leave `CLAUDE_SHIELD_SELF_EMAILS` unset |
| A `/skill` | Delete its file in `~/.claude/commands/` |
| The whole bundle | `./uninstall.sh` (keeps your notes + state), then restore `~/.claude.bak.*` for a clean slate |

Nothing here runs anything you can't see. Every hook is <150 lines of bash you can open and read.
