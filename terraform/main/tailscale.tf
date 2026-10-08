# The tailnet ACL policy is NOT managed in this repository: it is owned solely
# by kuchida1981/u-rei-infra (terraform/tailscale). This module only issues the
# VM's auth key, which requires `tag:vaultwarden-server` to already exist in
# that policy.
module "tailscale" {
  source = "../modules/tailscale"
}
