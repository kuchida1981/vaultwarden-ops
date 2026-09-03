output "pool_name" {
  description = "Full resource name of the Workload Identity Pool, for the CI service account's member binding."
  value       = google_iam_workload_identity_pool.github.name
}

output "provider_name" {
  description = "Full resource name to set as GCP_WORKLOAD_IDENTITY_PROVIDER in GitHub Actions secrets."
  value       = google_iam_workload_identity_pool_provider.github.name
}
