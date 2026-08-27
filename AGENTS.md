# Discourse Crimson Server List Agent Router

Canonical instructions for ChatGPT/Codex, Claude, and Gemini.

## Context routing
Current source/tests > `docs/ai/CURRENT_STATE.md` > nearest local `AGENTS.md` > stable docs > plans/history. Read only the current task surface:
- models/controllers/ownership/reviews/claims -> `app/AGENTS.md`
- probe jobs -> `app/jobs/AGENTS.md`
- network policy/adapters/probe service -> `lib/AGENTS.md`
- frontend routes/components -> `assets/javascripts/discourse/AGENTS.md`
- migrations/schema -> `db/AGENTS.md`
Use a three-file `docs/ai/work/<feature>/` packet only for genuine multi-session work.

## Fast task path
For non-trivial work, use `.agents/skills/task-packet/SKILL.md` before broad reads. Use `docs/ai/REPO_MAP.md` to locate code, `COMMANDS.md` only for validation, and `DECISIONS.md` only for network/ownership/architecture choices. Skip the formal packet for trivial one-file edits.

## Security and product invariants
This plugin owns moderated game-server listings, votes, reviews, ownership/claim transfer, live probe state, and public ranking/detail UI.

- Server ownership/admin authorization is server-side; client IDs/owner fields are never authoritative.
- Claim requests do not transfer ownership without authorized review/approval.
- Votes/reviews must preserve uniqueness/abuse controls defined by current code.
- Public serializers must not expose private management data or hidden connection details not intended for viewers.

### Network probing is a critical SSRF boundary
- Treat every submitted hostname/IP/port as hostile.
- Use the existing `CrimsonServerList::NetworkPolicy` and probe adapters; do not bypass them with raw socket/HTTP calls.
- Reject private, loopback, link-local, reserved, metadata, multicast, and otherwise forbidden destinations according to current policy.
- Validate after DNS resolution and at every relevant reconnect/redirect boundary so DNS rebinding/redirects cannot escape policy.
- Use strict connect/read/overall timeouts and bounded response sizes/work.
- Never log credentials or unnecessary private address data.
- Background refresh/probe jobs must be bounded, idempotent, retry-safe, and unable to create unbounded fan-out.

## Implementation/tests/safety
Use current Discourse APIs verified from source, smallest maintainable diffs, bounded queries, locale-backed UI, and meaningful authorization/error tests. Security/network/schema changes require the matching on-demand skill. Never claim unrun tests passed.

Stop for unresolved network policy, ownership/moderation, schema, security, or product ambiguity. Preserve unrelated work and `.claude/settings.local.json`; no force-push/reset/clean/branch deletion/deploy/destructive DB. Remote writes only when current task explicitly authorizes them. Prefer exact symbols/logs/diffs over broad scans.

Skills live under `.agents/skills/` and load on demand; use `task-packet` for non-trivial work.
