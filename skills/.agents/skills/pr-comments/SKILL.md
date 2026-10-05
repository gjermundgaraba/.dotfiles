---
name: pr-comments
description: Select and draft concise inline PR feedback in the user's voice.
disable-model-invocation: true
---

# PR Comments

Write comments that are worth interrupting the author for.

## Choose what to comment on

- Verify the finding against the diff and enough surrounding code, tests, documentation, or runtime behavior to support it.
- When reviewing an identified PR, check existing review threads and omit overlap. Rewriting supplied comment text alone does not require fetching the PR.
- Comment on a concrete defect, risk, maintainability problem, or meaningful test gap. Skip personal preference, speculative edge cases, and cleanup too small to merit action.
- Keep one issue per comment. Every comment is a change request: if the PR could be approved without it, leave no comment.
- Anchor each comment to the changed line it is about. Use a general comment only when no changed line carries the point. Only diff lines accept comments; if the relevant line is unchanged, use the nearest changed line that still reads naturally, or drop the comment.

## Write the comment

- Start lowercase unless the first token is an identifier or acronym.
- One short sentence by default, at most three, in prose with no lists. Add a sentence only when the consequence or missing context needs it.
- Say what is wrong and what it causes. Do not propose a fix, alternative design, or procedure; the author decides how. The suggestion-block rule below is the only exception.
- Use plain, natural language. Be direct without sounding formal or robotic; light personality is welcome when it fits, never forced. Ask questions directly, `<the thing>?` rather than `can we <the thing>?`, and skip politeness padding.
- Put identifiers in backticks. Avoid headings, labels, option menus, severity claims, and canned praise.
- Use straight quotation marks in prose. Avoid em/en dashes and double hyphens used as dashes; preserve verbatim code and quoted text.
- State material uncertainty directly; omit empty hedging.
- Use a GitHub suggestion block when the exact replacement is simple and will compile; otherwise use prose.

Consult [references/humanizer.md](references/humanizer.md) when a draft needs help removing formulaic phrasing. Preserve substantive claims and uncertainty.

For each draft, include the exact comment, its location, and enough surrounding code to evaluate it without opening the file. Do not add a review summary unless the user explicitly asks for one.

If authorized to add comments to GitHub, add them only to a pending review. When changing an existing pending review, modify or remove only the comments the user selected; leave every other pending comment unchanged. Never submit the review; leave every comment pending for the user to inspect, edit, and submit. After adding pending comments, provide a clickable link to the PR.

## Capture preferences when requested

Use this workflow only when the user has asked to capture durable preferences from comment feedback. Compare the proposal with the final result.

- Infer at most one reusable preference from that feedback.
- Ignore codebase facts, one-off circumstances, and preferences unlikely to apply across unrelated PRs.
- If a new preference is both general and not already covered, show the smallest proposed change to this `SKILL.md` and ask for confirmation.
- Edit the skill only after explicit confirmation. Tighten or replace an existing rule before adding another one.
- If there is no durable lesson, continue without proposing a skill change.

After an approved update, validate the skill and briefly state which general rule changed.
