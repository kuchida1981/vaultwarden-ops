## Context

`vaultwarden/Caddyfile` has a bare (non-`handle`) `reverse_proxy /notifications/hub vaultwarden:3012` directive placed ahead of the `handle /admin*` and catch-all `handle {}` blocks. Vaultwarden 1.29.0 merged its WebSocket server into the main Rocket process (port 80) and dropped the standalone port 3012 listener. The deployed image (`vaultwarden/server:1.37.2`, `vaultwarden/docker-compose.yml`) never exposes or references port 3012, so this rule proxies to an upstream that isn't listening there anymore.

## Goals / Non-Goals

**Goals:**
- Restore working WebSocket live sync notifications on the public domain.
- Keep the fix minimal and reversible.

**Non-Goals:**
- No change to `/admin` routing, TLS, or the tailnet-only listener (`http://:8080`).
- No change to `docker-compose.yml` or the Vaultwarden image version.
- No new explicit routing rule for `/notifications/hub` — the existing catch-all already covers it.

## Decisions

- **Delete the rule rather than repoint it to port 80.** The catch-all `handle { reverse_proxy vaultwarden:80 }` block already matches any path not claimed by an earlier `handle` block, including `/notifications/hub`. Adding `reverse_proxy /notifications/hub vaultwarden:80` as a replacement would duplicate that behavior for no benefit and leave a second reverse_proxy directive to keep in sync if the upstream ever changes.
  - Alternative considered: keep an explicit `/notifications/hub` rule pointed at `vaultwarden:80` for readability/self-documentation. Rejected — Caddy directive ordering between a bare `reverse_proxy` and `handle` blocks in the same server block is easy to get subtly wrong (this file's own history is an example), so one fewer routing rule is one fewer thing that can silently misorder.

## Risks / Trade-offs

- [Removing the rule silently changes nothing if Caddy's directive ordering was already routing `/notifications/hub` to the catch-all before this bug] → Verified by reading `docker-compose.yml`: port 3012 is never published or referenced anywhere in the compose stack, so the old rule could not have been the effective route. Confirm with `caddy validate` after the edit and, if a tailnet/staging environment is available, a live sync check (see tasks.md).

## Migration Plan

- Single-line removal in `vaultwarden/Caddyfile`, deployed via the existing `vaultwarden-deploy.yml` pipeline (same as any other Caddyfile change).
- Rollback: revert the commit; no data or state is affected.
