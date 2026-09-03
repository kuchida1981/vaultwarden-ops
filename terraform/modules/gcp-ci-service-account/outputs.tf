output "email" {
  description = "Service account email to set as GCP_SERVICE_ACCOUNT_EMAIL in GitHub Actions secrets."
  value       = google_service_account.terraform_ci.email
}
