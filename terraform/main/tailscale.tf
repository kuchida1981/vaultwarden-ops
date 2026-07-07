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
# a single resource. Applying this will overwrite whatever ACL currently
# exists for this tailnet. Before the first `terraform apply`, check the
# current policy at https://login.tailscale.com/admin/acl/file and merge in
# any custom rules you already rely on (e.g. anything specific to the NAS).
#
# The policy below intentionally mirrors Tailscale's zero-config default
# (accept all traffic between all devices) so existing devices, including
# the NAS, keep working exactly as before. The only new behavior is: (1) a
# tag owner for tag:vaultwarden-server, and (2) an `ssh` block that restricts
# `tailscale ssh` into that tag to the tailnet admin only.
resource "tailscale_acl" "this" {
  # The provider refuses to blindly clobber a hand-edited, non-default ACL
  # (safety guard: "You are trying to overwrite a non-default policy").
  # That's expected here: this tailnet's policy was already manually edited
  # (per the README bootstrap step, to pre-define tag:vaultwarden-server
  # before creating the OAuth client) before this resource was ever applied.
  # The content below was reviewed to be a superset of that manual edit, so
  # overwriting it is intentional, not accidental.
  overwrite_existing_content = true

  acl = jsonencode({
    tagOwners = {
      "tag:vaultwarden-server" = ["autogroup:admin"]
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
      }
    ]
  })
}
