# Crimson Server List app layer

- Server create/update/delete derives ownership/permissions server-side.
- Owner-only fields/actions and staff moderation stay protected from IDOR/mass assignment.
- ClaimRequest review is the only authorized ownership-transfer path; pending claims are not ownership.
- Vote/review uniqueness and current-user identity are persistence/server controlled.
- Public server detail/list output exposes only intended connection/status/metadata fields.
- Refresh actions enqueue/trigger bounded probe behavior rather than trusting client status/player counts.
