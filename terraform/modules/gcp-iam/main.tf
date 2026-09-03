terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

# Runtime identity attached to the VM. This is intentionally a *different*
# service account from the one GitHub Actions impersonates (terraform-ci,
# created in terraform/bootstrap): the VM only ever needs to read its two
# secrets, never to create/modify infrastructure or other secrets.
resource "google_service_account" "vm_runtime" {
  project      = var.project_id
  account_id   = "vaultwarden-vm"
  display_name = "Vaultwarden VM runtime"
}

# roles/monitoring.metricWriter and roles/logging.logWriter for this SA
# (letting the Ops Agent in startup-script.sh.tftpl report memory/disk/
# process metrics and logs) are granted in terraform/bootstrap, not here -
# see the comment there for why: setting project-level IAM policy is
# something CI's terraform-ci identity is intentionally never permitted to
# do itself.
resource "google_secret_manager_secret_iam_member" "admin_token_access" {
  project   = var.project_id
  secret_id = var.admin_token_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "tailscale_authkey_access" {
  project   = var.project_id
  secret_id = var.tailscale_authkey_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "smtp_username_access" {
  project   = var.project_id
  secret_id = var.smtp_username_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "smtp_password_access" {
  project   = var.project_id
  secret_id = var.smtp_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "nas_backup_password_access" {
  project   = var.project_id
  secret_id = var.nas_backup_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_runtime.email}"
}
