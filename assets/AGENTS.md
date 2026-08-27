# Crimson Server List frontend

- Consume plugin JSON APIs; never infer ownership/moderation authority from client state.
- Keep create/edit/claim/review/vote/refresh failure states explicit.
- Do not expose hidden management fields/ports if backend intentionally withholds them.
- Treat server descriptions/tags/URLs as untrusted display data; escape by default and avoid raw HTML.
- Use current Discourse/Glimmer routing conventions, locale-backed copy, mobile responsiveness, and light/dark compatibility.
- Large server-list/detail components should be read/changed by targeted symbol/section, not whole-file scans by default.
