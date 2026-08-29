# Current state

Functional main baseline before this state refresh: `207a2008c2360641fb7d1bbd38d3a1a9bf04bb0f`.

V2.8 scalable discovery is complete: `/servers` uses server-authoritative bounded filtering, deterministic pagination, stale-response protection and a metadata-only bootstrap payload instead of downloading the legacy catalogue slice. V2.7 online-back notification preferences, V2.6 private favorites/follows, V2.5 uptime history, and the V2.4 trust/moderation foundation remain live.

No active multi-session feature packet is recorded after the V2.8 release-state cleanup. Before new work inspect current branch/PR/source/tests and choose the next product step from current source rather than old plan documents.

Durable high-risk boundary: all live server probing remains behind the existing network policy/adapters with DNS/IP validation, strict timeouts and bounded work. Ownership, claims, reviews, reports, favorites and notification preferences remain server-authoritative. Discovery responses remain public-only and must not expose host/port/probe diagnostics.
