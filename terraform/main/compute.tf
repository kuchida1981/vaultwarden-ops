module "gcp_compute" {
  source = "../modules/gcp-compute"

  project_id  = var.project_id
  zone        = var.zone
  domain      = var.domain
  github_repo = var.github_repo

  network_self_link = module.gcp_network.network_self_link
  static_ip         = module.gcp_network.address
  disk_self_link    = module.gcp_disk.self_link
  vm_runtime_email  = module.gcp_iam.vm_runtime_email

  admin_token_secret_id         = module.gcp_secrets.admin_token_secret_id
  tailscale_authkey_secret_id   = module.gcp_secrets.tailscale_authkey_secret_id
  smtp_username_secret_id       = module.gcp_secrets.smtp_username_secret_id
  smtp_password_secret_id       = module.gcp_secrets.smtp_password_secret_id
  nas_backup_password_secret_id = module.gcp_secrets.nas_backup_password_secret_id

  smtp_host      = var.smtp_host
  smtp_port      = var.smtp_port
  smtp_security  = var.smtp_security
  smtp_from      = var.smtp_from
  smtp_from_name = var.smtp_from_name

  nas_backup_host     = var.nas_backup_host
  nas_backup_module   = var.nas_backup_module
  nas_backup_username = var.nas_backup_username

  # compute.tf's resource only *implicitly* depends on module.gcp_secrets/
  # module.gcp_iam through their output values (secret_id, SA email) - which
  # only orders it after the specific resources that produce those outputs
  # (the secrets themselves, the SA), not after the secret *versions* or the
  # secretAccessor IAM grants. The VM's startup-script needs both to exist
  # before it boots (it fetches secret values under that SA's identity), so
  # this explicit module-level depends_on - matching the original resource-
  # level depends_on before the module split - waits for every resource in
  # both modules to finish first.
  depends_on = [module.gcp_secrets, module.gcp_iam]
}
