# Customization Guide

This repository runs the maintainer's own Vaultwarden deployment, so several values default to the maintainer's environment (domain, GCP project, Tailscale tailnet, Brevo SMTP, a Synology NAS for backups). If you're forking this repo to self-host elsewhere, this document maps out what you need to change, what already ships with a safe-to-override default, and which two spots are hardcoded personal-infrastructure leftovers with no override path yet.

This is a companion map, not a replacement for [`README.md`](../README.md) — follow the README's Setup section step by step; use this doc to know which values along the way are yours to change.

## Required values (no usable default)

These have no default in `terraform/main/variables.tf` and must be supplied, or are secrets you must issue yourself. See the README's [Setup](../README.md#setup) section for how to obtain each one, and the [Secrets table](../README.md#5-register-github-actions-secrets) for the exact GitHub Actions Secret names.

| Value | Where it's defined | Notes |
|---|---|---|
| `project_id` | `terraform/main/variables.tf` | Your GCP project |
| `github_repo` | `terraform/main/variables.tf` | Your fork's `owner/repo`, used by the VM to clone `vaultwarden/` at boot |
| `tailscale_tailnet` | `terraform/main/variables.tf` | Your tailnet identifier |
| `tailscale_oauth_client_id` / `tailscale_oauth_client_secret` | `terraform/main/variables.tf` | Issued per README step 2 |
| `smtp_username` / `smtp_password` | `terraform/main/variables.tf` | Issued by whichever SMTP provider you use (see below) |
| `nas_backup_password` | `terraform/main/variables.tf` | Issued when you set up your own backup target (see below) |

All of the above map 1:1 to entries in the README's GitHub Secrets table — that table, not this document, is the source of truth for exact secret names.

## Maintainer-default values (safe to override)

These variables ship with a default tied to the maintainer's own setup, but are ordinary Terraform variables — override them with `-var` (or a `.tfvars` file) for your own environment. No code change is required.

| Variable | Default | Override for |
|---|---|---|
| `domain` | `vaultwarden.u-rei.com` | Your own domain |
| `region` / `zone` | `asia-northeast1` / `asia-northeast1-b` | Your preferred GCP region |
| `smtp_host` | `smtp-relay.brevo.com` | A different SMTP provider's relay host |
| `smtp_port` | `587` | Your provider's port |
| `smtp_security` | `starttls` | Your provider's required mode (`starttls`, `force_tls`, or `off`) |
| `smtp_from` | `vaultwarden@u-rei.com` | Your own send-only address |
| `smtp_from_name` | `vaultwarden` | Your preferred display name |
| `nas_backup_host` | `synology-nas` | Your own backup target's Tailscale hostname |
| `nas_backup_module` | `vaultwarden-backups` | Your rsync daemon's module name |
| `nas_backup_username` | `vaultwarden` | Your rsync daemon's account name |

**Switching SMTP providers**: `smtp_host`/`smtp_port`/`smtp_security`/`smtp_from`/`smtp_from_name`/`smtp_username`/`smtp_password` together fully describe the SMTP relay Vaultwarden sends through — override all of them for any provider that speaks standard SMTP, not just Brevo. No Terraform or application code assumes Brevo specifically.

**Switching backup targets**: `nas_backup_host`/`nas_backup_module`/`nas_backup_username`/`nas_backup_password` describe an rsync daemon endpoint. Any host running an rsync daemon reachable over your tailnet works, not just a Synology NAS — see the known constraint below for the one Synology-specific detail that isn't parameterized.

## Known constraints (hardcoded, no variable — documented, not fixed)

Two spots in the codebase assume the maintainer's personal infrastructure with no Terraform variable to override them. These are accepted as-is for now rather than parameterized in this change.

### `tag:n8n-server` in the Tailscale ACL

`terraform/main/tailscale.tf`'s `tailscale_acl` resource hardcodes a `tag:n8n-server` entry (in both `tagOwners` and an `ssh` block) tied to a sibling `n8n-ops` repository the maintainer runs privately. You won't have that repo.

- **Impact if left as-is**: applying Terraform just adds an unused tag/ACL entry to your own tailnet. Harmless — nothing in this repository ever provisions a device with that tag.
- **To remove it**: edit `terraform/main/tailscale.tf` directly, deleting the `tag:n8n-server` line from `tagOwners` and the corresponding entry from the `ssh` block.

### Synology-specific rsync excludes in the backup script

`terraform/main/templates/startup-script.sh.tftpl`'s NAS-push backup step excludes `#recycle`, `@eaDir`, and `lost+found` — paths Synology's DSM manages internally on its rsync targets.

- **Impact if left as-is**: on a non-Synology rsync target, these excludes are no-ops (the paths simply don't exist there) — safe either way.
- **To disable NAS backup entirely**: there is currently no variable to toggle it off. You'd need to edit the `backup.service`/`backup.timer` systemd unit definitions in the same template to remove the backup step.

## Optional, out-of-repo pieces

The uptime monitoring / alerting workflow mentioned in the README (an n8n workflow polling `/alive` and notifying Discord on failure) is **not managed by this repository at all** — it runs on a separate host the maintainer built manually. Vaultwarden operates normally without it. If you want equivalent monitoring, `/alive` is the integration point: any external uptime checker (n8n, Uptime Kuma, a cron job, a hosted service) can poll it the same way.
