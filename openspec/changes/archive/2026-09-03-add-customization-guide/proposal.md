## Why

This repository bakes in several assumptions from the maintainer's own environment (a specific domain, GCP project, Tailscale tailnet, Brevo SMTP relay, and a Synology NAS for backups). Someone forking the repo to self-host Vaultwarden elsewhere has no single place that maps out what to change, what already has a safe override, and which two spots are hardcoded personal-infrastructure leftovers with no override path. Issue #91 asks for that map.

## What Changes

- Add `docs/CUSTOMIZATION.md`, a fork/reuse guide covering:
  - The full set of values a forker must supply (cross-referencing the existing GitHub Secrets table and `terraform/main/variables.tf`, not duplicating them)
  - Values that ship with maintainer-specific defaults (Brevo SMTP host, `u-rei.com`-based addresses, `synology-nas`/`vaultwarden-backups` NAS defaults) but are safely overridable via `-var`
  - Two known unparameterized spots discovered during investigation, documented as accepted, harmless-but-unexplained constraints rather than bugs to fix in this change:
    - `terraform/main/tailscale.tf`'s `tailscale_acl` resource hardcodes a `tag:n8n-server` tagOwner/ssh entry tied to a sibling `n8n-ops` repo the forker won't have; applying as-is just adds an unused tag, and removing it means editing `tailscale.tf` directly (two locations)
    - `terraform/main/templates/startup-script.sh.tftpl` hardcodes Synology-specific rsync excludes (`#recycle`, `@eaDir`, `lost+found`) on the NAS-push leg; harmless on other rsync targets (paths simply don't exist), but there's no supported way to disable NAS backup entirely short of editing the systemd unit definitions in that same template
  - How to opt out of the two out-of-repo optional pieces (n8n-based uptime monitoring/alerting is not managed by this repo at all)
- Link `docs/CUSTOMIZATION.md` from the top of `README.md` and `README.ja.md` (near the existing "for me and my family" framing) so forkers find it before the Setup section

No Terraform, application, or CI behavior changes — this is documentation only.

## Capabilities

### New Capabilities
- `customization-guide`: documents which configuration values a fork must change, which ship with safe-to-override maintainer-specific defaults, and which known spots have no override path yet

### Modified Capabilities
(none — no spec-level behavior changes to existing capabilities)

## Impact

- Affected files: new `docs/CUSTOMIZATION.md`; small edits to `README.md` / `README.ja.md` to link it
- No changes to `terraform/`, `vaultwarden/`, or `.github/workflows/`
- No new secrets, variables, or infrastructure
