## Why

CI currently only runs `terraform plan` (which requires GCP credentials, so it never runs usefully on a fork). Terraform syntax errors, invalid Caddyfile config, and shell script mistakes in `startup-script.sh.tftpl` all currently reach `main` — or a fork's own branch — undetected until someone runs `terraform apply` or boots a VM. This is issue #90 and Step 2 of milestone `0.1`: build the safety net before the riskier refactors later in the milestone (and give forks/reusers of this repo a check that works without any secrets).

## What Changes

- Add a new GitHub Actions workflow that runs, on every pull request, without requiring any GCP credentials or repository secrets:
  - `terraform validate` (via `terraform init -backend=false`, no backend/auth needed) for both `terraform/main` and `terraform/bootstrap`
  - `tflint` (default core ruleset) for both `terraform/main` and `terraform/bootstrap`
  - `shellcheck` against `terraform/main/templates/startup-script.sh.tftpl`, with `SC2154` and `SC1091` excluded (both are false positives specific to this file — see design.md)
  - `caddy validate` against `vaultwarden/Caddyfile`, using the same `caddy:2.11.4` image pinned in `docker-compose.yml`
- Because none of these checks need secrets, the workflow can use a single plain `pull_request` trigger for both human-authored and Dependabot PRs — unlike `terraform-plan.yml`, it does not need the `pull_request`/`pull_request_target` split that exists there solely to get secrets into Dependabot's run.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `deployment-pipeline`: add a requirement that pull requests are checked by secret-free static analysis (terraform validate, tflint, shellcheck, caddy validate) independent of the existing GCP-authenticated `terraform plan` check.

## Impact

- New file: `.github/workflows/lint.yml` (name TBD in design/tasks).
- No changes to `terraform-plan.yml`, `terraform-apply.yml`, or `vaultwarden-deploy.yml`.
- No changes to Terraform resources, Caddyfile behavior, or the startup script itself — this only adds checks, it doesn't change what's being checked.
