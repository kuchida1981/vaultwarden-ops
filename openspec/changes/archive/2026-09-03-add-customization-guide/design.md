## Context

`README.md` already documents setup end-to-end (prerequisites, bootstrap, secrets table, DNS, verification) for the maintainer's own deployment. Issue #91 isn't asking for new setup content — it's asking for a single place that tells a forker, at a glance, which of those values are "must change," which are "maintainer defaults you can safely override," and which parts of the codebase still assume the maintainer's specific infrastructure with no override path at all.

Investigation (see conversation history / issue #91 exploration) found the environment-specific surface splits into three tiers:

1. Already a Terraform variable, already in the README Secrets table (`project_id`, `domain`, `tailscale_tailnet`, SMTP creds, NAS creds, etc.) — no gap, just needs a map.
2. A Terraform variable with a maintainer-flavored default that's meant to be overridden (`smtp_host` defaulting to Brevo, `nas_backup_host` defaulting to `synology-nas`) — no gap, just needs to be called out explicitly as "override this, don't fork it."
3. Hardcoded in Terraform/templates with **no** variable at all:
   - `terraform/main/tailscale.tf`'s `tailscale_acl` resource hardcodes `tag:n8n-server` (tagOwners + ssh block), coupling this public repo's ACL to a private sibling repo (`n8n-ops`) the forker won't have.
   - `terraform/main/templates/startup-script.sh.tftpl` hardcodes Synology-specific rsync excludes (`#recycle`, `@eaDir`, `lost+found`) on the NAS-push leg, and NAS backup has no on/off switch — disabling it means editing the systemd unit definitions in that same template.

## Goals / Non-Goals

**Goals:**
- Give a forker one document (`docs/CUSTOMIZATION.md`) that maps every value they need to change, without duplicating the authoritative secrets table in `README.md`.
- Explicitly name the two tier-3 spots as known, accepted constraints — what happens if you leave them, and exactly what to edit if you want them gone — so a forker isn't left debugging a mystery `tag:n8n-server` ACL entry or wondering why Synology paths appear in their startup script.
- Cross-link the new doc from both `README.md` and `README.ja.md` so it's discoverable before someone starts following the Setup steps.

**Non-Goals:**
- Do not parameterize the tier-3 spots (no `enable_n8n_tailscale_tag`, no `enable_nas_backup` variable). That's a Terraform change, explicitly deferred to a separate issue/change per the scoping decision made during exploration.
- Do not restate the full Setup walkthrough or Secrets table — `README.md` remains the source of truth for step-by-step setup; this doc is a companion map, not a replacement.
- No behavior change to any deployed system.

## Decisions

- **Location**: `docs/CUSTOMIZATION.md` (new `docs/` directory) rather than a new README section — the README is already long and setup-ordered; a customization map is a different reading mode (scan for "what applies to me") and deserves its own file, per the issue's own suggestion.
- **Relationship to README's secrets table**: cross-reference, don't duplicate. `CUSTOMIZATION.md` will point at `README.md`'s Secrets table and `terraform/main/variables.tf` rather than re-listing every variable with its own description, so the two docs can't drift out of sync.
- **Tier-3 framing**: document these as "known constraints from the maintainer's personal infrastructure" with concrete edit instructions (exact file + what to change), not as defects. This matches the decision (made during exploration) to keep this change docs-only rather than also touching Terraform.
- **Bilingual**: `README.md` and `README.ja.md` both get a one-line link near the top; `CUSTOMIZATION.md` itself is English-only (matching the split already used for design.md/proposal.md content vs README.ja.md, and keeping the new doc's maintenance burden to one file).

## Risks / Trade-offs

- [Doc drift: `CUSTOMIZATION.md` could go stale if `variables.tf` gains new variables] → Mitigation: doc explicitly points at `variables.tf` and the README secrets table as the live source rather than re-listing values inline, so most future variable additions don't require a `CUSTOMIZATION.md` edit.
- [Tier-3 items documented but not fixed — a forker still has to hand-edit `tailscale.tf`/`startup-script.sh.tftpl` if they want them gone] → Mitigation: acceptable per scoping decision; doc gives exact file/line guidance so the edit is mechanical, and a future change can add proper toggles if this recurs as friction.

## Migration Plan

Documentation-only change: add `docs/CUSTOMIZATION.md`, add one link line to `README.md` and `README.ja.md`. No deploy, no rollback concerns beyond a normal doc PR revert.

## Open Questions

None outstanding — scope was resolved during exploration (docs-only, tier-3 items documented as known constraints rather than parameterized).
