## 1. Draft docs/CUSTOMIZATION.md

- [x] 1.1 Create `docs/CUSTOMIZATION.md` with a "required values" section that cross-references (not duplicates) `README.md`'s Secrets table and `terraform/main/variables.tf` for `project_id`, `region`/`zone`, `domain`, `github_repo`, `tailscale_tailnet`, Tailscale OAuth credentials
- [x] 1.2 Add a "maintainer-default values" section flagging `smtp_host`/`smtp_port`/`smtp_security`/`smtp_from`/`smtp_from_name` (Brevo/`u-rei.com` defaults) and `nas_backup_host`/`nas_backup_module`/`nas_backup_username` (`synology-nas`/`vaultwarden-backups` defaults) as safely overridable via `-var`
- [x] 1.3 Add a "known constraints" section documenting the `tag:n8n-server` entries in `terraform/main/tailscale.tf` (both tagOwners and ssh block occurrences): practical impact of leaving as-is (unused tag, harmless) and exact edit needed to remove it
- [x] 1.4 In the same "known constraints" section, document the Synology-specific rsync excludes (`#recycle`, `@eaDir`, `lost+found`) in `terraform/main/templates/startup-script.sh.tftpl`: note they're no-ops on non-Synology targets, and that disabling NAS backup entirely requires editing the systemd unit definitions in that template (no variable toggle exists)
- [x] 1.5 Add an "optional, out-of-repo pieces" section noting the n8n-based uptime monitoring/alerting workflow is not managed by this repository and Vaultwarden operates normally without it, pointing to the `/alive` endpoint as the integration point

## 2. Link from READMEs

- [x] 2.1 Add a link to `docs/CUSTOMIZATION.md` near the top of `README.md`, before the "Setup" section
- [x] 2.2 Add the equivalent link to `README.ja.md` in the same relative position

## 3. Verify

- [x] 3.1 Re-read `docs/CUSTOMIZATION.md` end-to-end as if forking cold: confirm every required/overridable value it names still matches current `terraform/main/variables.tf` and the README Secrets table
- [x] 3.2 Confirm both README links render correctly and point to the right relative path
