# Auth key the VM consumes once at first boot to join the tailnet
# unattended. `preauthorized = true` combined with the ACL's tagOwners
# entry below means no manual approval step is needed in the Tailscale
# admin console.
resource "tailscale_tailnet_key" "vm" {
  reusable      = false
  ephemeral     = false
  preauthorized = true
  tags          = ["tag:vaultwarden-server"]
  expiry        = 7776000 # 90 days; only needs to survive until first boot
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
