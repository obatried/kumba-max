Confidence check on proposed changes. Run this before executing any prompt edit, code change, or plan modification to surface uncertainty and make it actionable.

## Instructions

For every change currently on the table (proposed edits, planned modifications, prompt updates), answer these three questions:

### 1. How confident are you in each change?

List every distinct change. For each one, rate your confidence (High / Medium / Low) and give a one-sentence reason.

Format:
- **[Change description]** -- [High/Medium/Low] -- [Why]

### 2. How would you actually make each change?

For each change, describe the concrete implementation: what file, what line, what gets added/removed/modified. If you're unsure how to implement it, say so explicitly.

Format:
- **[Change description]** -- [Implementation approach] -- Confidence in approach: [High/Medium/Low]

### 3. What would make you more confident?

For any change rated Medium or Low in either question above, answer: what specific information, clarification, or verification would raise your confidence? Be concrete. "More context" is not an answer. "Reading the current state of X file" or "Confirming whether Y is still true" is.

If everything is High confidence, say so and skip this section.

## Rules
- Be honest. Do not inflate confidence to avoid slowing things down.
- If you realize mid-answer that you need to read a file or verify something before you can answer accurately, say so instead of guessing.
- No preamble. Jump straight into the change list.
- Keep each answer tight. One sentence per change per question.
