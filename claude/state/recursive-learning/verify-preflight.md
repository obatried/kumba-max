# Verify-first preflight (universal verification principles — injected at session start)

Surfaced by `learn-preflight.sh` at the start of EVERY session. **Universal verification principles only** — ones that apply to any session regardless of what's being worked on. One short sentence each; salience comes from brevity. Project-specific lessons do NOT belong here — they live in their project's memory and surface on mention. Maintained by `/learn` (Step B): sharpen the matching line, never add a bullet, never let a line grow past one sentence.

This is a starter seed. `/learn` reshapes these lines around your actual recurring misses over time — but it keeps the file to ~5 short lines, on purpose.

- **Look for the playbook first.** Before any procedural task — or before calling something blocked or escalating — check your memory for an existing playbook and read it; ground facts and tool behavior in the authoritative source before experimenting live.
- **Verify a state before you assert it.** Done / failed / empty / passed / exists / saved / running — run the one direct check this turn, read a green result yourself, and run it in the context it will actually run in.
- **Wait for the durable signal before calling a gate done.** After a submit or click, confirm the item landed in its destination — not a transient toast or its disappearance from a queue — and for UI work, look at the screen rather than trusting a script's return.
- **Inferred ≠ observed.** A claim from a stale, partial, or adjacent source, an eyeballed count, or a causal story is a hypothesis — check the primary source, and treat your own empty/zero result as a possibly-bad filter before it's proof of absence.
- **A check you didn't re-run isn't proof.** Re-open every standard a gate names this turn, never chain the check and the commit in one call, and remember a green on a fixture is not a green on real input.
