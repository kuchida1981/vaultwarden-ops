output "state_bucket" {
  description = "GCS bucket name to use as the terraform/main remote state backend."
  value       = module.gcp_state_bucket.name
}

output "workload_identity_provider" {
  description = "Full resource name to set as GCP_WORKLOAD_IDENTITY_PROVIDER in GitHub Actions secrets."
  value       = module.gcp_wif.provider_name
}

output "terraform_ci_service_account_email" {
  description = "Service account email to set as GCP_SERVICE_ACCOUNT_EMAIL in GitHub Actions secrets."
  value       = module.gcp_ci_service_account.email
}
