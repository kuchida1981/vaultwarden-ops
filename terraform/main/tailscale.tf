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
# The policy below intentionally mirrors Tailscale's zero-config default
# (accept all traffic between all devices) so existing devices, including
# the NAS, keep working exactly as before. On top of that default: (1) tag
# owners for tag:vaultwarden-server and tag:n8n-server, and (2) `ssh` blocks
# that restrict `tailscale ssh` into either tag to the tailnet admin only.
resource "tailscale_acl" "this" {
  # The provider refuses to blindly clobber a hand-edited, non-default ACL
  # (safety guard: "You are trying to overwrite a non-default policy").
  # That's expected here: this tailnet's policy already has this resource's
  # own prior content applied, so overwriting it is intentional, not
  # accidental.
  overwrite_existing_content = true

  acl = jsonencode({
    tagOwners = {
      "tag:vaultwarden-server" = ["autogroup:admin"]
      "tag:n8n-server"         = ["autogroup:admin"]
    }
    acls = [
      {
        action = "accept"
        src    = ["*"]
        dst    = ["*:*"]
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
  })
}
