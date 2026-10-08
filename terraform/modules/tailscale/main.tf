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

# The tailnet's ACL policy (`tailscale_acl`) is no longer managed here. It is
# owned solely by kuchida1981/u-rei-infra (terraform/tailscale); change tags,
# rules and tests there. The `tag:vaultwarden-server` tag used by the key above
# must already exist in that policy's tagOwners before the key can be issued,
# so a new tag means a PR to u-rei-infra first.
#
# `destroy = false` is essential: it makes Terraform forget the resource
# without deleting it. Without it, removing the resource would delete the live
# policy and reset the tailnet to the default ACL, cutting every service off.
# Safe to delete this block once it has been applied.
removed {
  from = tailscale_acl.this

  lifecycle {
    destroy = false
  }
}
