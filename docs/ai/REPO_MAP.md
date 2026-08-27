# Repository map

Use this to choose paths before searching. Source code remains authoritative if the map becomes stale.

- `plugin.rb` — plugin entrypoint/registration.
- `app/` — listings, ownership, votes, reviews, claims/controllers; read `app/AGENTS.md`.
- `app/jobs/` — refresh/probe background jobs; read `app/jobs/AGENTS.md`.
- `lib/` — `NetworkPolicy`, game adapters, probe service; read `lib/AGENTS.md` only for network/probe tasks.
- `assets/javascripts/discourse/` — listing/detail/frontend UI; read local `AGENTS.md`.
- `db/` — migrations/schema/indexes; read `db/AGENTS.md`.
- `assets/` — presentation assets.
- `config/` — routes/settings/locales/configuration.
- `docs/` — AI state/workflow and stable docs; do not preload wholesale.

Fast read order: root `AGENTS.md` -> task packet -> nearest local `AGENTS.md` -> exact symbol/source -> exact test. Network decisions are on-demand, not default UI context.
