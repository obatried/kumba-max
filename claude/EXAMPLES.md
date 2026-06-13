# CLAUDE.md Examples

Worked ❌/✅ examples for sections in `CLAUDE.md`. Governed by `CLAUDE_MAINTENANCE.md` §5 (examples live here, not inline in rules).

_Added: 2026-04-23 | Last reviewed: 2026-04-23_

## Coverage

- §§1-4: core principles — examples below are minimal; the rules themselves are the spec
- §5 Skill Invocation: filled below
- §6 Read Source: filled below
- §7 Build Orchestration: filled below
- §8 Code-Review Feedback Handling: filled below
- §9 Persistence: filled below

---

## §5. Skill Invocation

**Setup:** End of a context-heavy session. Plan is to run `/end` to clean up before stopping.

**❌ Printed slash text instead of calling Skill**

> "All done for tonight.
>
> /end"

Problems: `/end` is plain text in the output. The end skill never runs. Cleanup is skipped. A Stop hook can audit the violation to `~/.claude/analytics/slash-text-violations.jsonl`.

**✅ Called the Skill tool**

> "All done for tonight. Running `/end` to clean up.
> [Skill({skill: "end"})]"

The skill fires. Cleanup happens. The final user-facing message doesn't end with a bare slash token.

The test: if your final message ends with `/<word>` text and you didn't call the Skill tool that turn, you violated §5.

---

## §6. Read Source, Not Just Summaries

**Setup:** User asks which OSS browser automation tool to use for daemon-style always-on scraping.

**❌ Recommended from the README**

> "I'd use browser-use based on their docs. They claim self-healing selectors and autonomous agents. 76K GitHub stars, well-maintained. The README shows a clean Python API."

Problems: every specific claim came from the README. No mention of retry semantics, what "self-healing" actually means in the code, how it handles headless detection. The README is a pitch, not a spec.

**✅ Read the source first**

> "Cloned browser-use. Read `browser_use/agent/service.py` and `browser_use/browser/browser.py`. Three things the README doesn't tell you:
>
> 1. Retries use exponential backoff with jitter, but only on specific Playwright errors — timeouts bubble unhandled (`service.py:214`).
> 2. The 'self-healing selectors' are a DOM-tree search, not ML. It refreezes the tree on every action, slow on heavy SPAs.
> 3. No built-in headless-stealth; you get bot-detected on Cloudflare sites without extra plugins.
>
> For your use case (overnight scraping, Cloudflare-protected targets), this probably isn't the fit. Actual rec: Playwright MCP + stealth plugins, or Bright Data if you don't want to manage stealth yourself."

The test: you can name one specific detail from the source that a README-only reader wouldn't know.

---

## §7. Build Orchestration

**Setup:** User asks "Add a `/signup/waitlist` page with a form that writes to a database and triggers a welcome email."

That touches a new route, a schema change, a new email template, and a new API handler. Matches every build-orchestrator trigger (new endpoint, migration, 3+ files, 3+ commits).

**❌ Started editing interactively**

> "Sure, starting with the page component."
>
> [Opens `app/signup/waitlist/page.tsx`. Commits. Opens API handler. Commits. Writes migration. Commits. Realizes email template isn't wired, fixes that. Commits.]

Problems: no plan.md, no manifest, no chunk boundaries. Commits land out of order (page references a schema that doesn't exist yet on first commit). Four commits in, still no QA. Exactly the failure mode a build orchestrator exists to prevent.

**✅ Invoked the orchestrator up front**

> "This is 4+ commits and touches schema, API, page, and email. Invoking the build orchestrator.
> [invokes the build orchestrator — e.g. `/build` from claude-code-build-kit; not bundled in kumba-max]"
>
> The orchestrator scaffolds `plan.md` and a state manifest. Plan: 1) migration, 2) API route, 3) page component, 4) email template, 5) QA. Each chunk gets committed in manifest order, state updated between chunks, QA at the end.

The test: for any task matching the triggers (new endpoint/migration/flag/cross-cutting/3+ commits), the first tool call should be the orchestrator invocation. If the first call was Edit or Write, you violated §7.

---

## §8. Code-Review Feedback Handling

**Setup:** Mid-task, the per-edit code review hook fires after an edit to a database client script.

```
[REAL — recommend fix] Unhandled error at db_client.py:47 —
if the RPC fails, `data` is None but the next line does data[0]['id'], will crash.
Add a guard.
```

**❌ Ignored REAL to keep momentum**

> "Pressing on with the next edit — I'll come back to that review finding after this chunk."

Problems: REAL means fix in the next edit, not later. "Later" becomes another commit boundary, another context switch, and the finding often gets buried. Violates §8's "fix in the next edit before continuing."

**✅ Fixed the REAL finding first**

> "Reviewer flagged `db_client.py:47` as REAL. Fixing before the next chunk."
>
> [Edits `db_client.py` to add the None guard, commits, then resumes the original task.]

**If instead it had been NOISE:**

```
[NOISE — ignore] Suggests type hints on internal helpers. Stylistic, not correctness.
```

> "Reviewer NOISE on type hints. Logged and moving on."

No fix. No detour. Log and continue.

**If ambiguous** (architectural, security, data integrity): dispatch a sub-agent to form a second POV per §8's heavy adjudication flow, then present both POVs + the reviewer for user decision if disagreement persists across 3 rounds.

The test: for every reviewer finding this turn, you can point to the action taken (fix / log-move / sub-agent) and it matches the tag.

---

## §9. Persistence

### 9a. Mid-task: don't give up prematurely

**Setup:** User asks "Pull the last 10 LinkedIn posts from my profile."

**❌ Gave up early**

> "I don't have direct access to LinkedIn. You'll need to export them yourself from LinkedIn's data download, then paste the contents here and I can parse them."

Problems: read one tool's limitation and stopped. Didn't try alternate paths (Apify, Firecrawl, Bright Data), didn't consult a second model, punted to the user.

**✅ Persisted per §9a**

> "Not going to route through manual export. Trying three approaches in order:
>
> 1. Apify LinkedIn scraper.
> 2. If that fails: Firecrawl scrape with logged-in session cookies.
> 3. If that fails: Bright Data SERP on `site:linkedin.com/in/<handle>/recent-activity`.
>
> [Runs Apify. Returns 10 posts.]
>
> Here are the 10 posts [structured list]. Apify worked on first try."

The test: three distinct attempts named. A second-model consult wasn't needed because approach 1 worked; if all three had failed, the consult fires before surfacing to the user.

---

### 9b. Unit boundaries: never summarize and wait

**Setup:** Just shipped commit 3 of a 7-commit feature plan. Four commits still queued.

**❌ Summarized and waited**

> "**Commit 3 of 7 shipped.**
>
> - Added the new `/api/users` endpoint
> - Wrote 4 tests, all passing
> - Updated the OpenAPI spec
>
> Ready for your review before I continue. Let me know when to move on."

Problems: queued work exists. "Let me know when to move on" is the punt. You explicitly don't want to approve at every boundary.

**✅ Kept going per §9b.1**

> "Commit 3 shipped (`/api/users` + tests + OpenAPI). Moving to commit 4 (permissions middleware)."

Then immediately tool-call into commit 4. No summary section, no wait.

**When to actually pause instead:**

- Context heavy (~50%+, many rounds in): fire the handoff per §9b.2, don't ask permission.
- Plan fully shipped AND nothing queued: offer one concrete next move with a POV, then do it if obvious or stop cleanly.
- Something genuinely needs user input (taste call, credential, preference): ask the specific question, don't stall.

The test: for the "shipped at boundary" message, you can point to the next tool call that starts the next unit. If the next thing is a user turn, you violated §9b.
