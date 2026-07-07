# NOTE: Vaultwarden also accepts a pre-hashed ADMIN_TOKEN (argon2 PHC string,
# via `vaultwarden hash`) for extra defense-in-depth. This uses a long random
# plaintext token for simplicity; consider hashing it if you want to harden
# the admin credential further.
resource "random_password" "admin_token" {
  length  = 48
  special = false
}

resource "google_secret_manager_secret" "admin_token" {
  project   = var.project_id
  secret_id = "vaultwarden-admin-token"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin_token" {
  secret      = google_secret_manager_secret.admin_token.id
  secret_data = random_password.admin_token.result
}

resource "google_secret_manager_secret" "tailscale_authkey" {
  project   = var.project_id
  secret_id = "vaultwarden-tailscale-authkey"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "tailscale_authkey" {
  secret      = google_secret_manager_secret.tailscale_authkey.id
  secret_data = tailscale_tailnet_key.vm.key
}
