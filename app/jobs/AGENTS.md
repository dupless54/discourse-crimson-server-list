# Server probe jobs

- Jobs call the existing policy-aware probe service; never implement a bypassing network path.
- Bound batch size, concurrency/fan-out, retries, per-probe time, and persisted error data.
- Re-running a scheduled/regular job must be safe and idempotent.
- A single hostile/unreachable server must not block the whole refresh set.
- Do not persist/log raw secrets or excessive network diagnostics.
