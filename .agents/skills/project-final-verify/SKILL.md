---
name: project-final-verify
description: Optionally perform an independent final verification for high-risk, ambiguous, or explicitly requested changes.
---
# Final verification
This skill is optional unless the current task explicitly requires it. Claude, Gemini, ChatGPT/Codex, and other AI reviewers are advisory only and their approval must not block an otherwise authorized merge.

When this skill is used, inspect the latest exact diff/source yourself and verify scope, trust/architecture boundaries, test evidence, and unresolved ambiguity. Return APPROVE, REJECT, or NEEDS_HUMAN. Reviewer approval never substitutes for required latest-head `Discourse Plugin` / required Discourse-owned CI GREEN, and a GREEN CI state never substitutes for explicit user merge authorization.
