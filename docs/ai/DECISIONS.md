# Durable decisions

Load only when network probing, ownership, moderation, or architecture behavior is relevant.

- Ownership/admin authority is server-side; claims transfer ownership only after authorized review.
- Votes/reviews preserve current uniqueness and abuse-control semantics.
- Probe destinations are hostile input and must pass `CrimsonServerList::NetworkPolicy` at DNS resolution and relevant reconnect/redirect boundaries.
- Private/loopback/link-local/reserved/metadata/multicast and otherwise forbidden destinations remain blocked for IPv4/IPv6.
- Probe work uses bounded connect/read/overall timeouts, response/work limits, and retry-safe/idempotent jobs.
- Public serializers never expose private management/connection data not intended for viewers.

Do not record temporary server outages or PR/CI state here; use `CURRENT_STATE.md` for volatile facts.
