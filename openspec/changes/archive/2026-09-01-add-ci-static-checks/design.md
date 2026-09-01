## Context

CI validation today is entirely `terraform-plan.yml`: `terraform plan` for `terraform/main` and `terraform/bootstrap`, both requiring GCP Workload Identity Federation auth. A fork or reuser without that GCP setup gets no CI signal at all. Meanwhile `terraform/main/templates/startup-script.sh.tftpl` (258 lines of bash embedded in a Terraform template) and `vaultwarden/Caddyfile` have no automated syntax checking whatsoever — issues there are only caught by booting a real VM or deploying to production.

All four tools below were run locally against this repo's actual files (via Docker, since none are installed on this machine) to confirm real behavior rather than assuming it:

- `terraform validate` (`terraform init -backend=false` + `validate`) passes cleanly for both `terraform/main` and `terraform/bootstrap`, confirmed against a clean `git archive` checkout.
- `tflint` (default core ruleset, no plugins) passes cleanly for both directories.
- `shellcheck` against `startup-script.sh.tftpl` fails by default: 19 `SC2154` warnings, one per Terraform `${var}` interpolation at the top of the file (shellcheck sees `${project_id}` etc. as bash variable references that are never assigned — it doesn't know Terraform fills them in before the script ever runs as bash), plus one `SC1091` info-level finding for `$(. /etc/os-release && ...)` (shellcheck can't follow a dynamically-sourced file it doesn't have access to). `shellcheck --exclude=SC2154,SC1091` passes cleanly. Note: the file's `#!/bin/bash` shebang is what lets shellcheck correctly parse it as bash despite the non-standard `.tftpl` extension — no `--shell=bash` flag is needed.
- `caddy validate --config` (via the `caddy:2.11.4` image, matching `docker-compose.yml`'s pinned version) against `vaultwarden/Caddyfile` with a dummy `DOMAIN` env var reports "Valid configuration".

## Goals / Non-Goals

**Goals:**
- Every PR gets terraform/shellcheck/Caddyfile validation without needing GCP secrets, so it works identically for this repo and any fork.
- Keep the new workflow fully independent of `terraform-plan.yml` — no shared jobs, no new coupling.

**Non-Goals:**
- Not adding a `tflint` provider-specific ruleset (e.g. the Google plugin) — the default core ruleset already passes cleanly and covers general Terraform correctness; a provider ruleset can be added later if a real gap shows up.
- Not changing `terraform-plan.yml`'s existing `pull_request`/`pull_request_target` split — that split exists specifically to get GCP secrets into Dependabot's run for `plan`, which this change's checks don't need.
- Not restructuring `startup-script.sh.tftpl` or the Terraform files themselves (that's issues #88/#89, explicitly out of milestone `0.1`'s scope).

## Decisions

- **New workflow file (`.github/workflows/lint.yml`), not new jobs in `terraform-plan.yml`.** `terraform-plan.yml`'s structure (path-relevance gating, `pull_request`/`pull_request_target` dual-trigger, `tfstate-main`/`tfstate-bootstrap` concurrency groups) exists entirely to manage GCP-authenticated, state-mutating operations safely. None of that applies here. Mixing a secret-free lint job into that file would inherit irrelevant complexity (e.g., having to decide whether lint should also skip on `steps.changes.outputs.relevant`) for no benefit.
- **Single plain `pull_request` trigger, no `pull_request_target`.** Because these checks need no secrets, there's no reason to give Dependabot's run elevated trigger permissions the way `terraform-plan.yml` must. Every PR, human or bot, takes the same code path.
- **No path filtering.** `terraform-plan.yml` filters by path because GCP auth + `terraform init` is comparatively expensive and only meaningful for `terraform/**` changes. These checks are cheap (no network auth, small fixed set of files) and simple correctness checks that would be silently skipped by an over-aggressive path filter aren't worth the added conditional complexity. The workflow runs unconditionally on every PR.
- **`shellcheck --exclude=SC2154,SC1091` scoped to `startup-script.sh.tftpl` specifically**, with a comment explaining why (Terraform interpolation false positive; unfollowable dynamic source), so a future contributor doesn't wonder why known-real categories of shellcheck findings are silenced. Excludes are passed as CLI flags in the workflow step, not a repo-wide `.shellcheckrc`, since there is currently only one shell script in the repo and a global config file would understate that these exclusions are specific to this file's Terraform-templated nature.
- **`caddy validate` pinned to `caddy:2.11.4`** (matching `docker-compose.yml`), not `caddy:latest`, so CI validates against the exact version actually deployed — a syntax feature valid in a newer Caddy but not 2.11.4 (or vice versa) would otherwise pass CI and fail at deploy time, or the reverse.

## Risks / Trade-offs

- [`shellcheck`'s exclusions could mask a *real* future SC2154 finding in code added later to the same file (e.g. a genuine undefined bash variable), not just the Terraform-interpolation false positives] → Mitigation: the exclusion is a blunt instrument (whole-file, not per-line `# shellcheck disable=SC2154` comments), but per-line disabling would require 19 individual annotations cluttering the variable-assignment block for no real safety gain, since that block is exactly where all the genuine Terraform interpolations live. If the file is ever split (issue #88), each resulting piece should re-evaluate whether it still needs this exclusion.
- [Pinning `caddy validate` to `2.11.4` means a Dependabot bump of the Caddy image in `docker-compose.yml` won't automatically update the validation step's version, silently drifting the two out of sync] → Mitigation: acceptable for now since Dependabot bumps are still caught by human review of the PR diff; not automating this further is in scope for a future improvement, not this change.

## Migration Plan

- Add-only change: one new workflow file. No existing workflow, Terraform resource, or runtime behavior changes.
- Rollback: delete the new workflow file; nothing else depends on it.
