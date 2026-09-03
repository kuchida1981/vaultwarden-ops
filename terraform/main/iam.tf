module "gcp_iam" {
  source = "../modules/gcp-iam"

  project_id                    = var.project_id
  admin_token_secret_id         = module.gcp_secrets.admin_token_secret_id
  tailscale_authkey_secret_id   = module.gcp_secrets.tailscale_authkey_secret_id
  smtp_username_secret_id       = module.gcp_secrets.smtp_username_secret_id
  smtp_password_secret_id       = module.gcp_secrets.smtp_password_secret_id
  nas_backup_password_secret_id = module.gcp_secrets.nas_backup_password_secret_id
}
