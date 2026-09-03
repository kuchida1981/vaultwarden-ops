output "admin_token_secret_id" {
  description = "Secret ID of the Vaultwarden admin token."
  value       = google_secret_manager_secret.admin_token.secret_id
}

output "tailscale_authkey_secret_id" {
  description = "Secret ID of the Tailscale auth key."
  value       = google_secret_manager_secret.tailscale_authkey.secret_id
}

output "smtp_username_secret_id" {
  description = "Secret ID of the SMTP username."
  value       = google_secret_manager_secret.smtp_username.secret_id
}

output "smtp_password_secret_id" {
  description = "Secret ID of the SMTP password."
  value       = google_secret_manager_secret.smtp_password.secret_id
}

output "nas_backup_password_secret_id" {
  description = "Secret ID of the NAS backup rsync password."
  value       = google_secret_manager_secret.nas_backup_password.secret_id
}
