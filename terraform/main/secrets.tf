module "gcp_secrets" {
  source = "../modules/gcp-secrets"

  project_id          = var.project_id
  tailscale_authkey   = module.gcp_tailscale.tailnet_key
  smtp_username       = var.smtp_username
  smtp_password       = var.smtp_password
  nas_backup_password = var.nas_backup_password
}
