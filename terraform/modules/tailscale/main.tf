terraform {
  required_providers {
    tailscale = {
      source = "tailscale/tailscale"
    }
  }
}

# Auth key the VM consumes at boot to join the tailnet unattended.
# `preauthorized = true` combined with the ACL's tagOwners entry below
# means no manual approval step is needed in the Tailscale admin console.
# `reusable = true` because the VM may be destroyed and recreated (e.g. a
# machine-type change); a one-time key would leave the replacement VM
# unable to join tailnet, and therefore unreachable via `tailscale ssh`.
# The key only ever tags a device as tag:vaultwarden-server, and is only
# readable by that VM's own runtime service account, so the exposure from
# reuse is minimal.
resource "tailscale_tailnet_key" "vm" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  tags          = ["tag:vaultwarden-server"]
  expiry        = 7776000 # 90 days; rotate by re-applying before this lapses
}

# WARNING: `tailscale_acl` manages the tailnet's *entire* ACL policy file as
# a single resource - the Tailscale API has no partial-update endpoint, so
# whichever Terraform state applies this resource last wins and overwrites
# the whole file. This repo is the sole owner of this resource for the
# tailnet: n8n-ops (a sibling repo sharing this tailnet) intentionally does
# NOT declare a `tailscale_acl` resource of its own - it only manages its
# own `tailscale_tailnet_key`, whose `tag:n8n-server` must already exist in
# the tagOwners map below before that key can be requested. This repo
# previously duplicated the whole ACL as a second resource in n8n-ops,
# which meant either repo applying could silently drop the other's tags -
# see n8n-ops issue "vaultwarden-ops' tailscale.tf lacked tag:n8n-server".
# Consolidating ownership here removes that race entirely: adding a new
# tailnet-connected service now means a PR to *this* file, not a
# repo-to-repo content sync.
#
# The policy below mirrors the live tailnet policy, which was edited by hand
# in the Tailscale admin console to accommodate projects outside these two
# repos (tag:claude-wrapper-server, tag:ci-blog-daily-post). Those tags and
# rules are declared here only so that applying this resource does not wipe
# them; they are NOT otherwise managed by this repo. Do not edit the ACL in
# the console: the next apply would revert it. Change this file instead.
#
# Notable points: (1) the first accept rule is scoped to tailnet members and
# the server tags rather than `*`, so tag:ci-blog-daily-post is deliberately
# NOT a source there and can only reach tag:claude-wrapper-server:18789 via
# the second rule; (2) `ssh` blocks restrict `tailscale ssh` into the
# vaultwarden/n8n tags to the tailnet admin only; (3) `tests` are validated
# by Tailscale on every save, guarding the ci-blog-daily-post isolation.
resource "tailscale_acl" "this" {
  # The provider refuses to blindly clobber a hand-edited, non-default ACL
  # (safety guard: "You are trying to overwrite a non-default policy").
  # That's expected here: the live policy has been reconciled into the
  # content below, so overwriting it is intentional, not accidental.
  overwrite_existing_content = true

  acl = jsonencode({
    tagOwners = {
      "tag:vaultwarden-server"    = ["autogroup:admin"]
      "tag:n8n-server"            = ["autogroup:admin"]
      "tag:claude-wrapper-server" = ["autogroup:admin"]
      "tag:ci-blog-daily-post"    = ["autogroup:admin"]
    }
    acls = [
      {
        action = "accept"
        src = [
          "autogroup:member",
          "tag:n8n-server",
          "tag:vaultwarden-server",
          "tag:claude-wrapper-server",
        ]
        dst = ["*:*"]
      },
      {
        action = "accept"
        src    = ["tag:ci-blog-daily-post"]
        dst    = ["tag:claude-wrapper-server:18789"]
      }
    ]
    ssh = [
      {
        action = "check"
        src    = ["autogroup:admin"]
        dst    = ["tag:vaultwarden-server"]
        users  = ["autogroup:nonroot", "root"]
      },
      {
        action = "check"
        src    = ["autogroup:admin"]
        dst    = ["tag:n8n-server"]
        users  = ["autogroup:nonroot", "root"]
      }
    ]
    tests = [
      {
        src    = "tag:ci-blog-daily-post"
        accept = ["tag:claude-wrapper-server:18789"]
        deny = [
          "tag:claude-wrapper-server:22",
          "tag:vaultwarden-server:80",
          "100.65.90.127:5000",
        ]
      }
    ]
  })
}
