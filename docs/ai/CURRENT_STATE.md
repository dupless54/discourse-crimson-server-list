# Current state

Current functional baseline before this modernization: `a4b1338b35d504027552f1c254078beb836bd47e` on `main`.

The plugin is on the V3 frontend line (`plugin.rb` currently declares `3.0.1`). `/servers` uses the V3 shell with Discover, Favorites, My Servers, and Administration panels. Public discovery is server-authoritative and paginated; favorites/follows and owner management remain private; approval, ownership claims, reports, DNS verification, uptime history, voting/reviews, back-online notifications, and bounded live probing remain active.

The current frontend modernization follows the live Discourse Developer Guides and current `discourse/discourse` patterns instead of relying on stale snippets. User-visible discovery/detail/route copy is locale-backed in English and Turkish, game-specific technical field labels are localized at presentation time, destructive listing deletion uses the Discourse dialog service, and create/edit/report modals follow current DModal form semantics with Discourse DButton actions. V3 tabs synchronize with browser history while preserving server-authoritative authorization gates.

Durable high-risk boundary: all live server probing remains behind the existing network policy/adapters with DNS/IP validation, strict timeouts, and bounded work. Ownership, claims, reviews, reports, favorites, notification preferences, owner-management state, approval, and moderation remain server-authoritative. Public discovery responses remain public-only and must not expose host/port/probe diagnostics.

Validation/merge boundary: only official Discourse Plugin CI (plus any other required Discourse-owned CI) on the latest exact PR head can authorize merge. Stale, missing, pending, cancelled, skipped, neutral, or unknown CI is not GREEN.
