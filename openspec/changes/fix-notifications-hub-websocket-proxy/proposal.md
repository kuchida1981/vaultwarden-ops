## Why

`vaultwarden/Caddyfile` proxies `/notifications/hub` to `vaultwarden:3012`, a WebSocket port Vaultwarden dropped in 1.29.0 when it folded the WebSocket server into the main process (port 80). The deployed image is pinned to 1.37.2, `WEBSOCKET_ENABLED` is `true`, but port 3012 is never exposed anywhere in `docker-compose.yml` — the route almost certainly no longer connects, silently breaking live sync push notifications. This is issue #92 and Step 1 of milestone `0.1`.

## What Changes

- Remove the `reverse_proxy /notifications/hub vaultwarden:3012` rule from `vaultwarden/Caddyfile`. The existing catch-all `handle { reverse_proxy vaultwarden:80 }` block already proxies any unmatched path — including `/notifications/hub` — to the correct upstream, so no replacement rule is needed.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `vaultwarden-service`: add a requirement that live sync WebSocket notifications (`/notifications/hub`) are proxied to Vaultwarden's main port, not a legacy dedicated port. This behavior was never previously captured as a spec requirement.

## Impact

- `vaultwarden/Caddyfile`: one line removed, no new routing logic added.
- No changes to `docker-compose.yml`, Terraform, or CI.
- No breaking change; purely a bug fix restoring intended (already-assumed) behavior.
