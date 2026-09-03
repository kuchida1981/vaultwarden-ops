## ADDED Requirements

### Requirement: Fork customization map
The repository SHALL provide a `docs/CUSTOMIZATION.md` document that maps every configuration value a forker must supply to run this project against their own environment, cross-referencing (not duplicating) the GitHub Secrets table in `README.md` and the variable definitions in `terraform/main/variables.tf`.

#### Scenario: Forker looks up a required value
- **WHEN** a forker reads `docs/CUSTOMIZATION.md` looking for what they must change to deploy under their own domain and GCP project
- **THEN** the document lists the required values (e.g. `project_id`, `domain`, `tailscale_tailnet`, GitHub Secrets) and points to their exact location in `README.md`'s Secrets table or `terraform/main/variables.tf`, without restating each variable's full description inline

### Requirement: Maintainer-default values flagged as overridable
`docs/CUSTOMIZATION.md` SHALL explicitly call out Terraform variables that ship with a maintainer-specific default value (e.g. `smtp_host` defaulting to Brevo's relay, `nas_backup_host` defaulting to `synology-nas`, `smtp_from` defaulting to a `u-rei.com` address) and state that these are safe to override via `-var` for a different SMTP provider or backup target.

#### Scenario: Forker wants a non-Brevo SMTP provider
- **WHEN** a forker reads the SMTP section of `docs/CUSTOMIZATION.md`
- **THEN** they learn that `smtp_host`/`smtp_port`/`smtp_security`/`smtp_from`/`smtp_from_name` are ordinary overridable Terraform variables, not something requiring a code change, and see which variable to set for a different relay

### Requirement: Unparameterized personal-infrastructure constraints documented
`docs/CUSTOMIZATION.md` SHALL document, as known accepted constraints rather than bugs, the two spots in the codebase that hardcode maintainer-specific infrastructure with no Terraform variable to override them:
- The `tag:n8n-server` tagOwners/ssh entries hardcoded in `terraform/main/tailscale.tf`'s `tailscale_acl` resource, which assume a sibling `n8n-ops` repository the forker will not have
- The Synology-specific rsync excludes (`#recycle`, `@eaDir`, `lost+found`) hardcoded in `terraform/main/templates/startup-script.sh.tftpl`, and the absence of any variable to disable NAS backup entirely

For each, the document SHALL state the practical impact of leaving it as-is and the exact file(s) to hand-edit if the forker wants it removed.

#### Scenario: Forker applies Terraform without an n8n deployment
- **WHEN** a forker runs `terraform apply` in `terraform/main` without operating an `n8n-ops`-style sibling deployment
- **THEN** `docs/CUSTOMIZATION.md` has already told them this only adds an unused `tag:n8n-server` tagOwner/ssh entry to their tailnet ACL, is harmless, and names `terraform/main/tailscale.tf` as the file to edit (both occurrences) if they want it removed

#### Scenario: Forker does not have a Synology NAS
- **WHEN** a forker wants to back up to a non-Synology target or skip NAS backup entirely
- **THEN** `docs/CUSTOMIZATION.md` explains that the `#recycle`/`@eaDir`/`lost+found` excludes are no-ops on other targets, and that fully disabling backup requires editing the systemd unit definitions in `terraform/main/templates/startup-script.sh.tftpl` since no variable currently toggles it

### Requirement: Optional out-of-repo pieces identified
`docs/CUSTOMIZATION.md` SHALL identify functionality mentioned in `README.md` that is not managed by this repository at all (the n8n-based uptime monitoring/alerting workflow), so a forker understands it can be skipped without affecting Vaultwarden's operation.

#### Scenario: Forker skips uptime monitoring
- **WHEN** a forker decides not to set up an equivalent to the maintainer's n8n uptime-monitoring workflow
- **THEN** `docs/CUSTOMIZATION.md` confirms this workflow lives outside this repository and that Vaultwarden functions normally without it, noting the `/alive` endpoint as the integration point if they later want to build their own

### Requirement: Discoverable from README
`README.md` and `README.ja.md` SHALL each link to `docs/CUSTOMIZATION.md` near the top of the document, before the Setup section, so a forker encounters it before following the step-by-step setup instructions.

#### Scenario: Forker starts reading README before setup
- **WHEN** a forker opens `README.md` (or `README.ja.md`) to begin setup
- **THEN** they encounter a link to `docs/CUSTOMIZATION.md` before reaching the "Setup" section
