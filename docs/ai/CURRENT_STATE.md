# Current state

Current functional baseline for this final V3 polish: `431ff4aebf481d549671e7cd870d9335fc11d6ba` on `main`, after the detail-tools modernization was merged. `plugin.rb` declares `3.0.1`.

The plugin is on the V3 frontend line. `/servers` uses the Discover, My Favorites, My Servers, and Administration shell. Public discovery is server-authoritative and paginated; favorites/follows and owner management remain private; approval, ownership claims, reports, DNS verification, uptime history, voting/reviews, back-online notifications, and bounded live probing remain active.

The V3 modernization follows the live Discourse Developer Guides and current `discourse/discourse` patterns instead of relying on stale snippets. User-visible discovery/detail/route copy is locale-backed in English and Turkish, game-specific technical field labels are localized at presentation time, destructive listing deletion uses the Discourse dialog service, and create/edit/report modals follow current DModal form semantics with Discourse DButton actions. V3 tabs synchronize with browser history and implement roving keyboard tab navigation with ArrowLeft, ArrowRight, Home, and End behavior. Featured cards preserve online/offline/maintenance/unknown status semantics. Private card-favorite state loads after render, exposes an explicit retry path after transient read failures, and synchronizes recovery across the shared favorites service.

The Administration panel refreshes its authoritative queue state on mount rather than trusting stale bootstrap arrays. Detail favorites/notifications, uptime history, and DNS verification expose explicit loading/error/retry states. Failed private favorite-state reads do not permit mutations from a false default state. DNS verification load failures do not fall through to an unrelated eligibility state, and clipboard errors do not reflect the private TXT challenge value into the error surface.

Durable high-risk boundary: all live server probing remains behind the existing network policy/adapters with DNS/IP validation, strict timeouts, and bounded work. Ownership, claims, reviews, reports, favorites, notification preferences, owner-management state, approval, and moderation remain server-authoritative. Public discovery responses remain public-only and must not expose host/port/probe diagnostics.

Validation/merge boundary: only official Discourse Plugin CI (plus any other required Discourse-owned CI) on the latest exact PR head can authorize merge. Stale, missing, pending, cancelled, skipped, neutral, or unknown CI is not GREEN.
