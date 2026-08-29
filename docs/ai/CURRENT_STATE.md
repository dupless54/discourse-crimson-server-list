# Current state

Functional main baseline before this state refresh: `f963c3322b9fef0780e5a68eff128b5cccbd6104`.

V2.9 Owner Panel is complete: private `GET /crimson-server-list/me/servers.json` is login-gated and strictly self-scoped, includes the owner's published/pending/disabled listings with bounded pagination and server-authoritative management state, and the `/servers` UI exposes the same data through a lazy responsive EN/TR panel without client-side ownership inference. Owner-private endpoint/probe fields remain private and are not added to public discovery.

V2.8 scalable discovery, V2.7 back-online notifications, V2.6 private favorites/follows, V2.5 uptime history and V2.4 trust/moderation remain live. The plugin header version is `2.9.0`.

No canonical V3 roadmap/TODO was found in the current repository search after V2.9. Before the next product feature, inspect fresh source/tests and select the smallest user-visible gap rather than inventing a milestone from stale plan material.

Durable high-risk boundary: all live server probing remains behind the existing network policy/adapters with DNS/IP validation, strict timeouts and bounded work. Ownership, claims, reviews, reports, favorites, notification preferences and owner-management state remain server-authoritative. Public discovery responses remain public-only and must not expose host/port/probe diagnostics.
