# Runtime identity attached to the VM. This is intentionally a *different*
# service account from the one GitHub Actions impersonates (terraform-ci,
# created in terraform/bootstrap): the VM only ever needs to read its two
# secrets, never to create/modify infrastructure or other secrets.
resource "google_service_account" "vm_runtime" {
  project      = var.project_id
  account_id   = "vaultwarden-vm"
  display_name = "Vaultwarden VM runtime"
}

resource "google_secret_manager_secret_iam_member" "admin_token_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.admin_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "tailscale_authkey_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.tailscale_authkey.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "smtp_username_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.smtp_username.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_runtime.email}"
}

resource "google_secret_manager_secret_iam_member" "smtp_password_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.smtp_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm_runtime.email}"
}
