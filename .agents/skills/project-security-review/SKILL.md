---
name: project-security-review
description: Review authorization, privacy, SSRF/network access, replay, input trust, and secret handling.
---
# Security review
Inspect exact diff. Check auth/IDOR, ownership/claim abuse, mass assignment, vote/review abuse, SSRF including DNS rebinding/redirects/IPv4/IPv6/private ranges, timeouts/response bounds, shell injection, replay/races, rate limits, and logging/secrets. Report concrete evidence; do not manufacture blockers.
