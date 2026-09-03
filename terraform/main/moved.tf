# State migration for the gcp-* module split (see openspec/changes/
# terraform-module-split). Each block maps a pre-split resource address to
# its new module-qualified address, so `terraform apply` reattaches the
# existing GCP resource instead of destroying and recreating it. Resource
# local names are unchanged from the pre-split files - only their address
# prefix (module.gcp_xxx.) changed. Requires Terraform >= 1.7 for the
# data-source moved block below.

# network.tf -> module.gcp_network
moved {
  from = data.google_compute_network.default
  to   = module.gcp_network.data.google_compute_network.default
}

moved {
  from = google_compute_firewall.allow_web
  to   = module.gcp_network.google_compute_firewall.allow_web
}

moved {
  from = google_compute_firewall.allow_iap_ssh
  to   = module.gcp_network.google_compute_firewall.allow_iap_ssh
}

moved {
  from = google_compute_address.vaultwarden
  to   = module.gcp_network.google_compute_address.vaultwarden
}

# disk.tf -> module.gcp_disk
moved {
  from = google_compute_disk.vaultwarden_data
  to   = module.gcp_disk.google_compute_disk.vaultwarden_data
}

# tailscale.tf -> module.gcp_tailscale
moved {
  from = tailscale_tailnet_key.vm
  to   = module.gcp_tailscale.tailscale_tailnet_key.vm
}

moved {
  from = tailscale_acl.this
  to   = module.gcp_tailscale.tailscale_acl.this
}

# secrets.tf -> module.gcp_secrets
moved {
  from = random_password.admin_token
  to   = module.gcp_secrets.random_password.admin_token
}

moved {
  from = google_secret_manager_secret.admin_token
  to   = module.gcp_secrets.google_secret_manager_secret.admin_token
}

moved {
  from = google_secret_manager_secret_version.admin_token
  to   = module.gcp_secrets.google_secret_manager_secret_version.admin_token
}

moved {
  from = google_secret_manager_secret.tailscale_authkey
  to   = module.gcp_secrets.google_secret_manager_secret.tailscale_authkey
}

moved {
  from = google_secret_manager_secret_version.tailscale_authkey
  to   = module.gcp_secrets.google_secret_manager_secret_version.tailscale_authkey
}

moved {
  from = google_secret_manager_secret.smtp_username
  to   = module.gcp_secrets.google_secret_manager_secret.smtp_username
}

moved {
  from = google_secret_manager_secret_version.smtp_username
  to   = module.gcp_secrets.google_secret_manager_secret_version.smtp_username
}

moved {
  from = google_secret_manager_secret.smtp_password
  to   = module.gcp_secrets.google_secret_manager_secret.smtp_password
}

moved {
  from = google_secret_manager_secret_version.smtp_password
  to   = module.gcp_secrets.google_secret_manager_secret_version.smtp_password
}

moved {
  from = google_secret_manager_secret.nas_backup_password
  to   = module.gcp_secrets.google_secret_manager_secret.nas_backup_password
}

moved {
  from = google_secret_manager_secret_version.nas_backup_password
  to   = module.gcp_secrets.google_secret_manager_secret_version.nas_backup_password
}

# iam.tf -> module.gcp_iam
moved {
  from = google_service_account.vm_runtime
  to   = module.gcp_iam.google_service_account.vm_runtime
}

moved {
  from = google_secret_manager_secret_iam_member.admin_token_access
  to   = module.gcp_iam.google_secret_manager_secret_iam_member.admin_token_access
}

moved {
  from = google_secret_manager_secret_iam_member.tailscale_authkey_access
  to   = module.gcp_iam.google_secret_manager_secret_iam_member.tailscale_authkey_access
}

moved {
  from = google_secret_manager_secret_iam_member.smtp_username_access
  to   = module.gcp_iam.google_secret_manager_secret_iam_member.smtp_username_access
}

moved {
  from = google_secret_manager_secret_iam_member.smtp_password_access
  to   = module.gcp_iam.google_secret_manager_secret_iam_member.smtp_password_access
}

moved {
  from = google_secret_manager_secret_iam_member.nas_backup_password_access
  to   = module.gcp_iam.google_secret_manager_secret_iam_member.nas_backup_password_access
}

# compute.tf -> module.gcp_compute
moved {
  from = google_compute_instance.vaultwarden
  to   = module.gcp_compute.google_compute_instance.vaultwarden
}
