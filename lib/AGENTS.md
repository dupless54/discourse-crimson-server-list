# Crimson Server List network layer

Critical SSRF boundary.

- `NetworkPolicy` is mandatory for all outbound server probes.
- Resolve hostnames safely and validate every resolved address before connection; account for DNS rebinding/multiple answers.
- Block loopback/private/link-local/reserved/metadata/multicast/unspecified ranges as current policy requires, for IPv4 and IPv6.
- Redirect/reconnect or protocol adapters must not escape the originally validated policy.
- Enforce strict connect/read/overall timeouts and bounded bytes/records.
- Game adapters parse untrusted remote responses defensively and return normalized `ProbeResult` values, not arbitrary remote objects.
- Do not add shell execution or unsafe command interpolation for probes.
