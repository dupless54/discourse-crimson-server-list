<p align="center">
  <a href="https://buymeacoffee.com/erespawn">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" width="217" height="60">
  </a>
</p>

# Discourse Crimson Server List

**Current release line: 3.0.1 (V3)**

A native Discourse game-server directory with moderated listings, server-authoritative discovery, live status checks, reviews, votes, ownership workflows, favorites, uptime history, DNS ownership verification, and private owner-management tools.

## Core Features

- V3 `/servers` application shell with Discover, My Favorites, My Servers, and Administration sections.
- Browser-history-aware V3 section navigation with accessible keyboard tab behavior.
- Public server detail pages with reviews, ratings, live status, uptime history, ownership tools, and reporting.
- Supported categories for Minecraft, FiveM, Rust, ARK, Silkroad Online, Metin2, Knight Online, and World of Warcraft.
- Server-authoritative search, game/tag/status/verified filters, sorting, and bounded pagination.
- Featured-server presentation that preserves online, offline, maintenance, and unknown status semantics.
- User-submitted listings with owner association and optional administrator approval.
- Owner editing and ownership-claim transfer through moderated workflows.
- Daily voting and unique 1–5 star/text reviews.
- DNS TXT ownership verification and verified-server presentation.
- Abuse reporting and administrator moderation queues.
- Private favorites/follows with optional back-online notifications and recoverable private-state loading.
- Uptime history with bounded retention and public 24-hour/7-day/30-day views.
- Periodic Sidekiq live-status refresh with short-lived cache data.
- Responsive desktop, tablet, and mobile interfaces using Discourse theme variables.
- English and Turkish localization.

## Recent Development Highlights

### 3.0 — V3 Application and Discourse UI Modernization

- Rebuilt `/servers` around the V3 Discover, My Favorites, My Servers, and Administration shell.
- Added browser-history-aware section navigation and keyboard-accessible ARIA tab behavior.
- Modernized create/edit/report flows with current Discourse `DModal`, `DButton`, dialog, and localized presentation patterns.
- Moved discovery, pagination, filtering, sorting, voting, favorites, ownership, moderation, and detail actions onto explicit loading/error/retry states while keeping server-authoritative contracts intact.
- Hardened administration queues against stale bootstrap data by refreshing authoritative admin state when the panel mounts.
- Hardened detail favorites, uptime history, and DNS verification against failed initial reads and unsafe default-state mutations.
- Preserved DNS TXT challenge privacy and prevented clipboard failures from reflecting the private challenge value into error output.
- Removed constructor-time async state mutations from affected Glimmer components and schedule initial reads after render to remain compatible with current Ember tracking rules.
- Added regression coverage for V3 browser history, admin queue refresh, DNS verification recovery, favorite-state recovery, uptime recovery, featured status semantics, and keyboard navigation.

### 2.9 — Owner Panel

- Added private `GET /crimson-server-list/me/servers.json`.
- The endpoint is always scoped to `owner_id = current_user.id`, including for administrator accounts.
- Published, pending-review, and disabled owner listings are available in one management view.
- Server-authoritative `publication_state`, `can_edit`, `can_refresh`, and `edit_requires_approval` values drive the UI.
- Owner-private host/port/probe information remains private and is never added to public discovery responses.
- The `/servers` page includes a lazy, responsive owner panel with bounded pagination and summary statistics.

### 2.8 — Scalable Discovery

- Added `/crimson-server-list/discovery.json` for server-side filtering, searching, sorting, and pagination.
- Added metadata-only `/crimson-server-list/bootstrap.json` so the initial page load no longer duplicates the full catalog payload.
- Search length, page size, page number, and sort modes are bounded and validated on the server.
- Public discovery explicitly strips private connection/probe diagnostics.

### 2.7 — Back-Online Notifications

- Users can opt into in-app recovery notifications for favorited servers.
- Notifications are sent only after a confirmed offline → online transition.
- Delivery is idempotent and batched for large follower sets.

### 2.6 — Favorites / Follow

- Private per-user favorites with duplicate protection and bounded limits.
- Notification preference stored on the follow relationship.

### 2.5 — Uptime History

- Probe results are stored in bounded time buckets.
- Configurable retention with batched cleanup.
- Uptime calculations ignore unknown/maintenance samples instead of inventing availability data.

### 2.4 — Trust, Moderation, and Abuse Protection

- DNS TXT server verification.
- Listing reports and administrator review queues.
- Owner self-voting/self-review protection.
- Discourse `RateLimiter` protections for submissions, votes, reviews, and ownership claims.

## Live Query Adapters

| Game | Adapter | Result |
| --- | --- | --- |
| Minecraft Java | Server List Ping | Online players / capacity |
| FiveM | `dynamic.json`, fallback `players.json` | Online players / capacity |
| Rust | Steam A2S_INFO | Online players / capacity |
| ARK | Steam A2S_INFO | Online players / capacity |
| Silkroad Online | Bounded TCP reachability | Online / offline |
| Metin2 | Bounded TCP reachability | Online / offline |
| Knight Online | Bounded TCP reachability | Online / offline |
| World of Warcraft | Bounded realm TCP reachability | Online / offline |

For games without a universal unauthenticated player-count protocol, the plugin reports reachability instead of fabricating player numbers.

## Network Security

Live probing is a security-sensitive SSRF boundary. The plugin routes submitted targets through its existing network policy and probe adapters:

- private, loopback, link-local, reserved, metadata, multicast, and other forbidden destinations are rejected;
- DNS/IP validation is applied before connections and at relevant reconnect/redirect boundaries;
- connections use strict timeouts and bounded work;
- public serializers do not expose owner-private host/port/probe diagnostic data.

Do not bypass `CrimsonServerList::NetworkPolicy` when extending probe behavior.

## Installation

Add the plugin to your Discourse container configuration:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/dupless54/discourse-crimson-server-list.git
```

Then rebuild Discourse:

```bash
cd /var/discourse
./launcher rebuild app
```

Enable the plugin in site settings and configure the server-list options required by your community.

## Development

The repository uses official Discourse Plugin CI and exact-head validation for delivery. Start with [`AGENTS.md`](AGENTS.md) before changing network, ownership, moderation, or public-serialization behavior. Version-sensitive frontend work should follow current Discourse core patterns and the live Discourse Developer Guides referenced by the repository documentation.

## Support

If this plugin helps your gaming community, you can support continued development through the Buy Me a Coffee banner at the top of this README.
